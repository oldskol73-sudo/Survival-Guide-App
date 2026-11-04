"""Makes scanned PDFs (pages are pictures, no text) searchable by adding an invisible OCR text layer.

    python -I tool/ocr_library.py [--workers 3] [--only SUBSTRING] [--limit N]

For every PDF under library/ that has no extractable text, each page is rendered, read with RapidOCR, and the words
are written back invisibly on top of the page image, so the page looks identical but the app can search it.
The original file is first moved to library/_ocr_originals/ (a folder the app ignores). Safe to re-run: files that
already have text are skipped. Needs:  python -m pip install rapidocr-onnxruntime pymupdf
"""
import os
import shutil
import sys
import time
from multiprocessing import Pool

import numpy as np
import pymupdf

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
LIB = os.path.join(ROOT, 'library')
BACKUP = os.path.join(LIB, '_ocr_originals')
SKIP_TOP = ('_', '11_Maps', '10_Kiwix_ZIM')
DPI = 150

_engine = None


def engine():
    global _engine
    if _engine is None:
        from rapidocr_onnxruntime import RapidOCR
        _engine = RapidOCR(intra_op_num_threads=5, inter_op_num_threads=1)
    return _engine


def has_text(path):
    try:
        with pymupdf.open(path) as d:
            return any(len(pg.get_text().split()) > 5 for pg in d)
    except Exception:
        return True  # unreadable: leave alone


def scanned_files():
    for top in sorted(os.listdir(LIB)):
        if top.startswith(SKIP_TOP[0]) or top in SKIP_TOP[1:]:
            continue
        for dp, _, fs in os.walk(os.path.join(LIB, top)):
            for f in sorted(fs):
                if f.lower().endswith('.pdf'):
                    p = os.path.join(dp, f)
                    if not has_text(p):
                        yield p


def ocr_one(path):
    t0 = time.time()
    rel = os.path.relpath(path, LIB)
    out_tmp = path + '.ocr.tmp'
    words = 0
    try:
        with pymupdf.open(path) as doc:
            for pg in doc:
                pix = pg.get_pixmap(dpi=DPI)
                img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.h, pix.w, pix.n)
                if pix.n == 4:
                    img = img[:, :, :3]
                elif pix.n == 1:
                    img = np.repeat(img, 3, axis=2)
                res, _ = engine()(np.ascontiguousarray(img))
                k = 72.0 / DPI
                for box, text, _score in (res or []):
                    xs = [pt[0] for pt in box]
                    ys = [pt[1] for pt in box]
                    h = max(ys) - min(ys)
                    size = max(4.0, min(h * k * 0.9, 40.0))
                    try:
                        pg.insert_text((min(xs) * k, max(ys) * k), text, fontsize=size, render_mode=3)
                        words += len(text.split())
                    except Exception:
                        pass
            doc.save(out_tmp, garbage=3, deflate=True)
    except Exception as e:
        if os.path.exists(out_tmp):
            os.remove(out_tmp)
        return rel, False, f'{type(e).__name__}: {e}', time.time() - t0
    if words < 20:
        os.remove(out_tmp)
        return rel, False, f'OCR found only {words} words', time.time() - t0
    dest = os.path.join(BACKUP, rel)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.move(path, dest)
    shutil.move(out_tmp, path)
    return rel, True, f'{words} words', time.time() - t0


if __name__ == '__main__':
    a = sys.argv[1:]
    workers = int(a[a.index('--workers') + 1]) if '--workers' in a else 3
    only = a[a.index('--only') + 1] if '--only' in a else None
    limit = int(a[a.index('--limit') + 1]) if '--limit' in a else None
    files = [p for p in scanned_files() if not only or only.lower() in p.lower()]
    # smallest first, so most files finish early and the two big books run last
    files.sort(key=os.path.getsize)
    if limit:
        files = files[:limit]
    print(len(files), 'scanned PDFs to read', flush=True)
    ok = 0
    with Pool(workers) as pool:
        for rel, good, msg, secs in pool.imap_unordered(ocr_one, files):
            ok += good
            print(('OK   ' if good else 'FAIL ') + f'{secs:6.0f}s  {rel}  ({msg})', flush=True)
    print(f'done: {ok}/{len(files)} made searchable', flush=True)
