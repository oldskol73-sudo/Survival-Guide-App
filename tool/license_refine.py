"""Second pass over the 'unknown' documents in LICENSE_AUDIT.csv. READ-ONLY on the library; rewrites the CSV.

    python -I tool/license_refine.py [AUDIT.csv]

Green and amber rows are kept exactly as they are. Each 'unknown' row is re-read (first four and last two pages, plus
the PDF's author/producer fields) and filed by the owner's rules:

  college / university named         -> amber (green if it is plainly a cooperative-extension / land-grant publication)
  private industry named             -> red   (company, Inc, LLC, Ltd, Corp, publisher, manufacturer)
  one individual, no organisation    -> stays unknown
  nothing found                      -> stays unknown

College is tested first. Screening aid only, not legal clearance: a person should check anything before it ships.
"""
import csv
import os
import re
import sys
from multiprocessing import Pool

import pymupdf

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
LIB = os.path.join(ROOT, 'library')
I = re.IGNORECASE

COLLEGE = re.compile(r'\b(?:college|university|universities|institute of technology|polytechnic|school of (?:engineering|agriculture|medicine|public health))\b', I)
EXTENSION = re.compile(r'cooperative extension|extension service|land[- ]grant|agricultural experiment station|extension bulletin|\bextension\b.{0,30}\b(?:university|college)\b', I)
INDUSTRY = re.compile(
    # Company forms only. Ordinary words such as "limited", "incorporated", "manufacturing" are far too common in prose.
    r'\b(?:inc\.?|l\.l\.c\.?|llc|ltd\.?|corporation|corp\.|gmbh|plc|pty\.?)(?=[\s,.;)]|$)'
    r'|\band co\.|\b& co\b|\bco\., |\bcompany,? (?:inc|ltd)'
    r'|\bpublishing (?:co|company|group|house|inc)\b|\bpublishers?\b'
    r'|\bmanufactured by\b|\bproduced by .{0,40}(?:inc|ltd|llc|corp)', I)


def refine(path):
    try:
        with pymupdf.open(path) as d:
            n = len(d)
            idx = list(range(min(4, n))) + list(range(max(4, n - 2), n))
            text = ' '.join(d[i].get_text() for i in idx)[:40000]
            meta = ' '.join(str(v) for k, v in (d.metadata or {}).items() if k in ('author', 'producer', 'creator', 'title') and v)
    except Exception:
        return path, 'unknown', 'UNREADABLE'
    text = ' '.join((meta + ' ' + text).split())
    col = COLLEGE.search(text)
    if col:
        return path, ('green' if EXTENSION.search(text) else 'amber'), 'COLLEGE:' + col.group(0).lower()
    ind = INDUSTRY.search(text)
    if ind:
        return path, 'red', 'INDUSTRY:' + ind.group(0).lower()
    return path, 'unknown', ''


def main():
    csv_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'docs', 'store', 'LICENSE_AUDIT.csv')
    with open(csv_path, newline='', encoding='utf-8') as f:
        rows = list(csv.DictReader(f))
    todo = [os.path.join(LIB, r['file']) for r in rows if r['class'] == 'unknown']
    print(len(todo), 'unknown documents to re-read', flush=True)
    result = {}
    with Pool(8) as pool:
        for path, cls, sig in pool.imap_unordered(refine, todo, chunksize=4):
            result[os.path.relpath(path, LIB)] = (cls, sig)
    moved = {'green': 0, 'amber': 0, 'red': 0, 'unknown': 0}
    for r in rows:
        if r['class'] == 'unknown' and r['file'] in result:
            cls, sig = result[r['file']]
            moved[cls] += 1
            if cls != 'unknown':
                r['class'] = cls
                r['signals'] = (r['signals'] + ';' if r['signals'] else '') + 'PASS2_' + sig
            elif sig:
                r['signals'] = (r['signals'] + ';' if r['signals'] else '') + sig
    with open(csv_path, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=['folder', 'file', 'class', 'signals', 'pages'])
        w.writeheader()
        w.writerows(rows)
    print('unknowns re-filed:', moved)
    tot = {}
    for r in rows:
        tot[r['class']] = tot.get(r['class'], 0) + 1
    print('overall now:', {k: tot.get(k, 0) for k in ('green', 'amber', 'red', 'unknown')})
    by = {}
    for r in rows:
        by.setdefault(r['folder'], {}).setdefault(r['class'], 0)
        by[r['folder']][r['class']] += 1
    for folder in sorted(by):
        c = by[folder]
        print(f"  {folder:28} green={c.get('green', 0):3d} amber={c.get('amber', 0):3d} red={c.get('red', 0):3d} unknown={c.get('unknown', 0):3d}")


if __name__ == '__main__':
    main()
