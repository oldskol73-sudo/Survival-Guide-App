"""Pack a tile dump from tool/pmtiles_extract.dart into a PMTiles v3 archive, ready to host:

    python tool/pmtiles_pack.py tools/maps/midatlantic            # writes tools/maps/midatlantic.pmtiles

Layout (same as Protomaps' own files, so any PMTiles reader works):
    header (127 bytes) | root directory | metadata JSON | leaf directories | tile data
Tiles are clustered (stored in tile-id order), identical tiles are stored once, and runs of consecutive ids that
share a tile are collapsed. Directories and metadata are gzip compressed; tiles keep their source gzip.
Standard library only.
"""
import gzip
import hashlib
import json
import os
import struct
import sys

HEADER_LEN = 127
ROOT_MAX = int(os.environ.get('PMTILES_ROOT_MAX', 16384 - HEADER_LEN))  # header + root stay inside the first 16 KB (env override is for tests)


def zxy_to_tileid(z, x, y):
    n = 1 << z
    acc = ((1 << (2 * z)) - 1) // 3
    d = 0
    s = n >> 1
    while s > 0:
        rx = 1 if (x & s) else 0
        ry = 1 if (y & s) else 0
        d += s * s * ((3 * rx) ^ ry)
        if ry == 0:
            if rx == 1:
                x = n - 1 - x
                y = n - 1 - y
            x, y = y, x
        s >>= 1
    return acc + d


def varint(v):
    out = bytearray()
    while True:
        b = v & 0x7F
        v >>= 7
        if v:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def serialize_directory(entries):
    """entries: list of (tile_id, offset, length, run_length) sorted by tile_id."""
    out = bytearray(varint(len(entries)))
    last = 0
    for e in entries:
        out += varint(e[0] - last)
        last = e[0]
    for e in entries:
        out += varint(e[3])
    for e in entries:
        out += varint(e[2])
    for i, e in enumerate(entries):
        if i > 0 and e[1] == entries[i - 1][1] + entries[i - 1][2]:
            out += varint(0)
        else:
            out += varint(e[1] + 1)
    return gzip.compress(bytes(out), compresslevel=9, mtime=0)


def build_directories(entries):
    """Returns (root_bytes, leaves_bytes). Uses one flat root if it fits, otherwise splits into leaf directories."""
    flat = serialize_directory(entries)
    if len(flat) <= ROOT_MAX:
        return flat, b''
    leaf_size = int(os.environ.get('PMTILES_LEAF_SIZE', 4096))
    while True:
        leaves = bytearray()
        root_entries = []
        for i in range(0, len(entries), leaf_size):
            chunk = serialize_directory(entries[i:i + leaf_size])
            root_entries.append((entries[i][0], len(leaves), len(chunk), 0))
            leaves += chunk
        root = serialize_directory(root_entries)
        if len(root) <= ROOT_MAX:
            return root, bytes(leaves)
        leaf_size = int(leaf_size * 1.2) + 1


def main(base):
    meta = json.load(open(base + '.json', encoding='utf-8'))
    md = meta['metadata']
    w, s, e, n = meta['bounds']
    dump = base + '.tiles'
    out_path = base + '.pmtiles'

    # Pass 1: index the dump (id, where the bytes are, size, content hash).
    index = []  # (tile_id, dump_offset, length, digest)
    with open(dump, 'rb') as f:
        pos = 0
        while True:
            h = f.read(13)
            if not h:
                break
            z, x, y, ln = struct.unpack('<BIII', h)
            data = f.read(ln)
            if len(data) != ln:
                raise SystemExit('truncated tile dump')
            index.append((zxy_to_tileid(z, x, y), pos + 13, ln, hashlib.blake2b(data, digest_size=16).digest()))
            pos += 13 + ln
    index.sort(key=lambda r: r[0])
    for a, b in zip(index, index[1:]):
        if a[0] == b[0]:
            raise SystemExit(f'duplicate tile id {a[0]}')
    print(f'{len(index)} tiles indexed')

    # Pass 2: decide where each distinct tile goes, build entries (with run lengths).
    seen = {}      # digest -> (offset, length) in the output tile-data section
    order = []     # (dump_offset, length) of each distinct tile, in output order
    next_off = 0
    entries = []   # (tile_id, offset, length, run_length)
    for tile_id, doff, ln, dg in index:
        if dg in seen:
            off, ln = seen[dg]
        else:
            off = next_off
            seen[dg] = (off, ln)
            order.append((doff, ln))
            next_off += ln
        if entries and entries[-1][1] == off and entries[-1][0] + entries[-1][3] == tile_id:
            last = entries[-1]
            entries[-1] = (last[0], last[1], last[2], last[3] + 1)
        else:
            entries.append((tile_id, off, ln, 1))
    tile_data_len = next_off
    print(f'{len(order)} distinct tiles, {len(entries)} directory entries, {tile_data_len / 1048576:.1f} MB of tile data')

    root, leaves = build_directories(entries)
    metadata = {k: v for k, v in md.items() if k in ('vector_layers', 'name', 'description', 'attribution', 'version', 'type')}
    metadata['attribution'] = '<a href="https://www.openstreetmap.org/copyright">&copy; OpenStreetMap contributors (ODbL)</a>; Natural Earth'
    metadata['survivalnode:source'] = 'Protomaps basemap ' + str(md.get('version', '')) + ' (OpenStreetMap data, ODbL)'
    metadata['survivalnode:region'] = os.path.basename(base)
    meta_bytes = gzip.compress(json.dumps(metadata).encode('utf-8'), compresslevel=9, mtime=0)

    root_off = HEADER_LEN
    meta_off = root_off + len(root)
    leaf_off = meta_off + len(meta_bytes)
    data_off = leaf_off + len(leaves)
    addressed = sum(en[3] for en in entries)
    cz = min(meta['maxzoom'], 10)
    i32 = lambda v: int(round(v * 1e7))
    header = struct.pack(
        '<7sB11Q6B4iB2i',
        b'PMTiles', 3,
        root_off, len(root), meta_off, len(meta_bytes), leaf_off, len(leaves), data_off, tile_data_len,
        addressed, len(entries), len(order),
        1, 2, 2, 1, meta['minzoom'], meta['maxzoom'],           # clustered, gzip dirs, gzip tiles, MVT, zooms
        i32(w), i32(s), i32(e), i32(n),
        cz, i32((w + e) / 2), i32((s + n) / 2),
    )
    assert len(header) == HEADER_LEN, len(header)

    tmp = out_path + '.part'
    with open(tmp, 'wb') as out, open(dump, 'rb') as src:
        out.write(header)
        out.write(root)
        out.write(meta_bytes)
        out.write(leaves)
        for doff, ln in order:
            src.seek(doff)
            out.write(src.read(ln))
    os.replace(tmp, out_path)
    print(f'wrote {out_path}: {os.path.getsize(out_path) / 1048576:.1f} MB '
          f'(root {len(root)} bytes, {len(leaves) / 1024:.0f} KB of leaf directories)')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: python tool/pmtiles_pack.py <base path of .tiles/.json dump>')
    main(sys.argv[1])
