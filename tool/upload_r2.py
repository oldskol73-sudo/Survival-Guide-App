"""Upload a large file (a .pmtiles map) to Cloudflare R2 using the S3 API. Standard library only.

    python tool/upload_r2.py --selftest                       # checks the request signing, no network, no keys
    python tool/upload_r2.py --check                          # tests your keys against the bucket, changes nothing
    python tool/upload_r2.py tools/maps/mid-atlantic.pmtiles  # uploads (needs the 4 variables below)

Credentials are read from environment variables so they never touch a file or the shell history of this repo:
    R2_ACCOUNT_ID         Cloudflare account id (R2 > Overview)
    R2_ACCESS_KEY_ID      from R2 > Manage API tokens > Create API token (Object Read & Write, this bucket only)
    R2_SECRET_ACCESS_KEY  shown once when the token is created
    R2_BUCKET             bucket name

The file is sent in 64 MiB parts, each retried, so a dropped connection costs one part, not the whole upload.
"""
import datetime
import hashlib
import hmac
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

PART_SIZE = 64 * 1024 * 1024


def _hmac(key, msg):
    return hmac.new(key, msg.encode('utf-8'), hashlib.sha256).digest()


def _q(s):
    return urllib.parse.quote(s, safe='-_.~')


def sign(method, host, path, query, headers, payload_hash, amz_date, access_key, secret, region='auto', service='s3'):
    """AWS Signature Version 4. Returns the Authorization header value. `headers` must include host and x-amz-date."""
    date = amz_date[:8]
    canon_path = urllib.parse.quote(path, safe='/-_.~')
    canon_query = '&'.join(f'{_q(k)}={_q(v)}' for k, v in sorted(query.items()))
    lowered = {k.lower(): ' '.join(str(v).split()) for k, v in headers.items()}
    names = sorted(lowered)
    canon_headers = ''.join(f'{n}:{lowered[n]}\n' for n in names)
    signed = ';'.join(names)
    canonical = '\n'.join([method, canon_path, canon_query, canon_headers, signed, payload_hash])
    scope = f'{date}/{region}/{service}/aws4_request'
    to_sign = '\n'.join(['AWS4-HMAC-SHA256', amz_date, scope, hashlib.sha256(canonical.encode('utf-8')).hexdigest()])
    k = _hmac(('AWS4' + secret).encode('utf-8'), date)
    for part in (region, service, 'aws4_request'):
        k = _hmac(k, part)
    sig = hmac.new(k, to_sign.encode('utf-8'), hashlib.sha256).hexdigest()
    return f'AWS4-HMAC-SHA256 Credential={access_key}/{scope}, SignedHeaders={signed}, Signature={sig}'


def selftest():
    """Amazon's published Signature V4 examples for S3 (docs: "Authenticating requests: Using the Authorization header")."""
    ak, sk = 'AKIAIOSFODNN7EXAMPLE', 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
    empty = hashlib.sha256(b'').hexdigest()
    get = sign('GET', 'examplebucket.s3.amazonaws.com', '/test.txt', {},
               {'host': 'examplebucket.s3.amazonaws.com', 'range': 'bytes=0-9', 'x-amz-content-sha256': empty, 'x-amz-date': '20130524T000000Z'},
               empty, '20130524T000000Z', ak, sk, region='us-east-1')
    put_hash = hashlib.sha256(b'Welcome to Amazon S3.').hexdigest()
    put = sign('PUT', 'examplebucket.s3.amazonaws.com', '/test$file.text', {},
               {'date': 'Fri, 24 May 2013 00:00:00 GMT', 'host': 'examplebucket.s3.amazonaws.com', 'x-amz-content-sha256': put_hash,
                'x-amz-date': '20130524T000000Z', 'x-amz-storage-class': 'REDUCED_REDUNDANCY'},
               put_hash, '20130524T000000Z', ak, sk, region='us-east-1')
    ok1 = get.endswith('Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41')
    ok2 = put.endswith('Signature=98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd')
    print('GET example signature matches Amazon\'s published value:', 'yes' if ok1 else 'NO')
    print('PUT example signature matches Amazon\'s published value:', 'yes' if ok2 else 'NO')
    return ok1 and ok2


class R2Error(Exception):
    def __init__(self, status, code, message):
        super().__init__(f'HTTP {status} {code}: {message}')
        self.status = status
        self.code = code


HINTS = {
    'InvalidAccessKeyId': 'The Access Key ID is not one Cloudflare knows. Use the "Access Key ID" from the token page, not the "Token value".',
    'SignatureDoesNotMatch': 'The Secret Access Key does not match the Access Key ID (or has a stray space). Use the "Secret Access Key", not the "Token value".',
    'AccessDenied': 'The token is valid but not allowed to do this. It needs Object Read & Write on bucket "survival-node-maps".',
    'NoSuchBucket': 'No bucket with that name on this account. Check R2_BUCKET and R2_ACCOUNT_ID.',
    'RequestTimeTooSkewed': 'This PC\'s clock is off by more than 15 minutes. Fix the Windows time and retry.',
}


def check():
    """Cheap credentials test: lists one object. Prints a plain-English result and changes nothing."""
    r2 = R2()
    if not re.fullmatch(r'[0-9a-f]{32}', r2.key):
        print('Note: the Access Key ID should be 32 characters (letters a-f and digits).')
    if not re.fullmatch(r'[0-9a-f]{64}', r2.secret):
        print(f'Note: the Secret Access Key should be exactly 64 characters (letters a-f and digits); yours is {len(r2.secret)}.')
        print('      Cloudflare shows a separate, shorter "Token value". That is NOT the secret. Use the 64-character "Secret Access Key".')
    try:
        # Start and immediately cancel an upload: needs only the write permission the real upload needs.
        _, _, body = r2.request('POST', '_credentials_check', {'uploads': ''})
        upload_id = re.search(rb'<UploadId>([^<]+)</UploadId>', body).group(1).decode()
        r2.request('DELETE', '_credentials_check', {'uploadId': upload_id})
        print(f'OK: credentials work and can write to bucket "{r2.bucket}". Nothing was stored.')
        return True
    except R2Error as e:
        print(f'FAILED: {e}')
        print('Hint:', HINTS.get(e.code, 'See the code above; it comes straight from Cloudflare.'))
        return False


class R2:
    def __init__(self):
        try:
            self.account = os.environ['R2_ACCOUNT_ID']
            self.key = os.environ['R2_ACCESS_KEY_ID']
            self.secret = os.environ['R2_SECRET_ACCESS_KEY']
            self.bucket = os.environ['R2_BUCKET']
        except KeyError as e:
            raise SystemExit(f'Missing environment variable {e}. See the top of this file.')
        self.host = f'{self.account}.r2.cloudflarestorage.com'

    def request(self, method, key, query=None, body=b'', extra=None):
        query = query or {}
        path = f'/{self.bucket}/{key}'
        payload_hash = hashlib.sha256(body).hexdigest()
        amz_date = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        headers = {'host': self.host, 'x-amz-date': amz_date, 'x-amz-content-sha256': payload_hash}
        headers.update(extra or {})
        auth = sign(method, self.host, path, query, headers, payload_hash, amz_date, self.key, self.secret)
        qs = '&'.join(f'{_q(k)}={_q(v)}' for k, v in sorted(query.items()))
        url = f'https://{self.host}{urllib.parse.quote(path, safe="/-_.~")}' + (f'?{qs}' if qs else '')
        req = urllib.request.Request(url, data=body if method in ('PUT', 'POST') else None, method=method)
        for k, v in headers.items():
            if k != 'host':
                req.add_header(k, v)
        req.add_header('Authorization', auth)
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                return r.status, dict(r.headers), r.read()
        except urllib.error.HTTPError as e:
            # Cloudflare explains the problem in an XML body (no secrets in it): show it.
            text = e.read().decode('utf-8', 'replace')
            code = re.search(r'<Code>([^<]*)</Code>', text)
            msg = re.search(r'<Message>([^<]*)</Message>', text)
            raise R2Error(e.code, code.group(1) if code else '', msg.group(1) if msg else text[:300]) from None


def upload(path):
    r2 = R2()
    key = os.path.basename(path)
    size = os.path.getsize(path)
    print(f'Uploading {key} ({size / 1048576:.1f} MB) to bucket {r2.bucket}')
    _, _, body = r2.request('POST', key, {'uploads': ''}, extra={'content-type': 'application/octet-stream', 'cache-control': 'public, max-age=86400'})
    upload_id = re.search(rb'<UploadId>([^<]+)</UploadId>', body).group(1).decode()
    parts = []
    try:
        with open(path, 'rb') as f:
            n = 0
            while True:
                chunk = f.read(PART_SIZE)
                if not chunk:
                    break
                n += 1
                for attempt in range(5):
                    try:
                        _, hdrs, _ = r2.request('PUT', key, {'partNumber': str(n), 'uploadId': upload_id}, body=chunk)
                        break
                    except (R2Error, urllib.error.URLError, TimeoutError, ConnectionError) as e:
                        if isinstance(e, R2Error) and e.status < 500:
                            raise
                        print(f'  part {n} attempt {attempt + 1} failed ({e}); retrying')
                        time.sleep(2 * (attempt + 1))
                else:
                    raise SystemExit(f'part {n} failed 5 times')
                etag = {k.lower(): v for k, v in hdrs.items()}['etag']
                parts.append((n, etag))
                print(f'  part {n} done ({min(n * PART_SIZE, size) / 1048576:.0f} / {size / 1048576:.0f} MB)')
        xml = '<CompleteMultipartUpload>' + ''.join(f'<Part><PartNumber>{n}</PartNumber><ETag>{e}</ETag></Part>' for n, e in parts) + '</CompleteMultipartUpload>'
        r2.request('POST', key, {'uploadId': upload_id}, body=xml.encode())
    except BaseException:
        try:
            r2.request('DELETE', key, {'uploadId': upload_id})
        except Exception:
            pass
        raise
    print(f'Done. The object is "{key}". Make the bucket public (or attach a custom domain) and use that address in the catalog.')


if __name__ == '__main__':
    if sys.argv[1:] == ['--selftest']:
        sys.exit(0 if selftest() else 1)
    if sys.argv[1:] == ['--check']:
        sys.exit(0 if check() else 1)
    if len(sys.argv) != 2 or not os.path.isfile(sys.argv[1]):
        raise SystemExit(__doc__)
    try:
        upload(sys.argv[1])
    except R2Error as e:
        print(f'\nUpload failed: {e}')
        print('Hint:', HINTS.get(e.code, 'The code above comes straight from Cloudflare.'))
        sys.exit(1)
