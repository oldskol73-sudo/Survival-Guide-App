"""Pack a tile dump from tool/pmtiles_extract.dart into an MBTiles file:  python tool/pack_mbtiles.py <base>

Reads <base>.tiles and <base>.json, writes <base>.mbtiles (gzip vector tiles, TMS rows, as the app's tile server expects).
"""
import json
import os
import sqlite3
import struct
import sys

base = sys.argv[1]
meta = json.load(open(base + '.json', encoding='utf-8'))
out = base + '.mbtiles'
if os.path.exists(out):
    os.remove(out)
db = sqlite3.connect(out)
db.executescript("""
CREATE TABLE metadata (name TEXT, value TEXT);
CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row);
""")
md = meta['metadata']
w, s, e, n = meta['bounds']
rows = {
    'name': md.get('name', 'Protomaps Basemap'),
    'format': 'pbf',
    'type': 'baselayer',
    'version': str(md.get('version', '1')),
    'description': md.get('description', ''),
    'attribution': 'OpenStreetMap contributors (ODbL); Natural Earth',
    'bounds': f'{w},{s},{e},{n}',
    'center': f'{(w + e) / 2},{(s + n) / 2},{min(meta["maxzoom"], 10)}',
    'minzoom': str(meta['minzoom']),
    'maxzoom': str(meta['maxzoom']),
    'json': json.dumps({'vector_layers': md.get('vector_layers', [])}),
}
db.executemany('INSERT INTO metadata VALUES (?, ?)', rows.items())

count = 0
with open(base + '.tiles', 'rb') as f:
    while True:
        h = f.read(13)
        if not h:
            break
        z, x, y, ln = struct.unpack('<BIII', h)
        data = f.read(ln)
        if len(data) != ln:
            raise SystemExit('truncated tile dump')
        db.execute('INSERT OR REPLACE INTO tiles VALUES (?, ?, ?, ?)', (z, x, (1 << z) - 1 - y, data))
        count += 1
db.commit()
db.execute('VACUUM')
db.close()
print(f'{count} tiles -> {out} ({os.path.getsize(out) / 1048576:.1f} MB)')
