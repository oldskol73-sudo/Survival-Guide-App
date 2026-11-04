"""Builds a desktop copy of the app's page-level search index (same FTS5 settings) from the library PDFs,
so retrieval can be tested on the PC without the phone.   python tool/rag_eval/build_index.py OUT.db"""
import os, sys, sqlite3, json, re
from multiprocessing import Pool
import fitz

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
LIB = os.path.join(ROOT, 'library')
CATS = {c['dir']: c['id'] for c in json.load(open(os.path.join(ROOT, 'assets/catalog/categories.json'), encoding='utf-8'))['categories']}
CATS['Wildflower_Doomsday_Disks'] = 'longterm'

def files():
    for top in sorted(os.listdir(LIB)):
        if top not in CATS or top.startswith('_') or top in ('11_Maps', '10_Kiwix_ZIM'):
            continue
        for dp, _, fs in os.walk(os.path.join(LIB, top)):
            for f in fs:
                if f.lower().endswith('.pdf'):
                    yield CATS[top], os.path.join(dp, f)

def extract(a):
    cat, path = a
    pages = []
    try:
        with fitz.open(path) as d:
            for i, pg in enumerate(d):
                t = ' '.join(pg.get_text().split())
                if t:
                    pages.append((i + 1, t))
    except Exception as e:
        return cat, path, None, str(e)
    return cat, path, pages, None

if __name__ == '__main__':
    out = sys.argv[1]
    if os.path.exists(out):
        os.remove(out)
    db = sqlite3.connect(out)
    db.executescript('''
      CREATE TABLE documents(id INTEGER PRIMARY KEY, title TEXT, category TEXT, rel_path TEXT, pages INTEGER, text_pages INTEGER);
      CREATE VIRTUAL TABLE pages_fts USING fts5(body, title, category UNINDEXED, doc_id UNINDEXED, page UNINDEXED,
        tokenize='porter unicode61 remove_diacritics 2', prefix='2 3');
    ''')
    todo = list(files())
    print(len(todo), 'pdfs', flush=True)
    n = 0
    with Pool(8) as pool:
        for cat, path, pages, err in pool.imap_unordered(extract, todo, chunksize=2):
            n += 1
            title = os.path.splitext(os.path.basename(path))[0].replace('_', ' ')
            cur = db.execute('INSERT INTO documents(title,category,rel_path,pages,text_pages) VALUES (?,?,?,?,?)',
                             (title, cat, os.path.relpath(path, LIB), 0 if pages is None else max(p for p, _ in pages) if pages else 0, 0 if pages is None else len(pages)))
            did = cur.lastrowid
            if pages:
                db.executemany('INSERT INTO pages_fts(body,title,category,doc_id,page) VALUES (?,?,?,?,?)',
                               [(t, title, cat, did, p) for p, t in pages])
            if n % 50 == 0:
                print(n, flush=True); db.commit()
    db.commit()
    r = db.execute('select count(*), sum(text_pages=0) from documents').fetchone()
    print('docs', r[0], 'with no text (scanned):', r[1], 'pages', db.execute('select count(*) from pages_fts').fetchone()[0])
