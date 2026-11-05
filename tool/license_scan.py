"""First-pass licence scan of the library PDFs. READ-ONLY: it never changes a document.

    python -I tool/license_scan.py [OUT.csv]

For each PDF in the sorted library folders it reads the first four and last two pages and looks for the wording
publishers use to state their terms (public domain, Creative Commons, "all rights reserved", a (c) line, an ISBN,
government agency names, USAID). It then files the document as:

  green    government or openly licensed wording, and no copyright claim: likely free to redistribute
  amber    mixed signals, "free to copy" or non-commercial wording, or USAID / NGO material to check one by one
  red      a copyright claim with nothing that offsets it: do not redistribute without permission
  unknown  no licence wording found (very common for older or scanned material)

This is a screening aid, NOT legal clearance. A document can carry a notice that this scan misses, and a notice can
be wrong. Anything you plan to distribute should be checked by a person.
"""
import csv
import os
import re
import sys
from multiprocessing import Pool

import pymupdf

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
LIB = os.path.join(ROOT, 'library')
SKIP_TOP = ('_', '11_Maps', '10_Kiwix_ZIM', 'Wildflower_Doomsday_Disks')

I = re.IGNORECASE
GREEN = {
    'PUBLIC_DOMAIN': re.compile(r'public domain', I),
    'CREATIVE_COMMONS': re.compile(r'creative commons|\bcc[ -]by\b', I),
    'NOT_COPYRIGHTED': re.compile(r'not (?:be )?copyrighted|no copyright|not subject to copyright', I),
    'MILITARY': re.compile(r'department of the (?:army|navy|air force)|approved for public release|distribution (?:is )?unlimited|navedtra|naval education and training|\bneets\b', I),
    'US_AGENCY': re.compile(r'government printing office|federal emergency management|environmental protection agency|department of agriculture|department of energy|national weather service|peace corps|centers for disease control', I),
}
RED = {
    'ALL_RIGHTS_RESERVED': re.compile(r'all rights reserved', I),
    'NO_PART': re.compile(r'no part of this (?:publication|book|work|manual)', I),
    'COPYRIGHT_LINE': re.compile(r'©|\(c\)\s*\d{4}|copyright\s*(?:©\s*)?\d{4}', I),
    'ISBN': re.compile(r'\bISBN\b', I),
    'NO_REPRODUCTION': re.compile(r'reproduced.{0,40}without.{0,30}permission', I),
}
AMBER = {
    'PERMISSION_TO_COPY': re.compile(r'permission (?:is |are )?(?:hereby )?(?:granted|given).{0,60}(?:copy|reproduce|reprint)', I),
    'FREE_TO_COPY': re.compile(r'free to (?:copy|reproduce|distribute|share)|may be (?:freely )?(?:copied|reproduced|reprinted)', I),
    'NON_COMMERCIAL': re.compile(r'non-?commercial', I),
    'USAID': re.compile(r'\busaid\b|agency for international development', I),
    'NGO_SERIES': re.compile(r'volunteers in technical assistance|\bvita\b|practical action|hesperian|appropriate technology', I),
}
TITLE_GREEN = re.compile(r'^(?:FM|TM|TC|ST|AFH)[ _-]?\d|\bNEETS\b|NAVEDTRA|\bFEMA\b|\bUSDA\b|\bEPA\b', I)


def scan(path):
    try:
        with pymupdf.open(path) as d:
            n = len(d)
            idx = list(range(min(4, n))) + list(range(max(4, n - 2), n))
            text = ' '.join(d[i].get_text() for i in idx)[:40000]
    except Exception as e:
        return path, 'unknown', ['UNREADABLE'], 0
    text = ' '.join(text.split())
    g = [k for k, rx in GREEN.items() if rx.search(text)]
    r = [k for k, rx in RED.items() if rx.search(text)]
    a = [k for k, rx in AMBER.items() if rx.search(text)]
    if TITLE_GREEN.search(os.path.basename(path)):
        g.append('TITLE_GOV_SERIES')
    strong_g = [k for k in g if k != 'US_AGENCY']  # an agency name alone (e.g. cited as a source) is weak
    if r and not strong_g and not g:
        cls = 'red'
    elif g and not r:
        cls = 'green'
    elif g and r:
        cls = 'amber'
    elif a:
        cls = 'amber'
    elif r:
        cls = 'red'
    else:
        cls = 'unknown'
    # USAID-linked material always needs a person to look, unless it states public domain / Creative Commons outright
    if 'USAID' in a and not ({'PUBLIC_DOMAIN', 'CREATIVE_COMMONS', 'NOT_COPYRIGHTED'} & set(g)) and cls in ('green', 'unknown', 'red'):
        cls = 'amber'
    return path, cls, g + r + a, (n if text else 0)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'docs', 'store', 'LICENSE_AUDIT.csv')
    files = []
    for top in sorted(os.listdir(LIB)):
        if top.startswith(SKIP_TOP[0]) or top in SKIP_TOP[1:] or not os.path.isdir(os.path.join(LIB, top)):
            continue
        for dp, _, fs in os.walk(os.path.join(LIB, top)):
            for f in sorted(fs):
                if f.lower().endswith('.pdf'):
                    files.append(os.path.join(dp, f))
    print(len(files), 'PDFs to screen', flush=True)
    rows = []
    with Pool(8) as pool:
        for path, cls, flags, pages in pool.imap_unordered(scan, files, chunksize=4):
            rel = os.path.relpath(path, LIB)
            rows.append((rel.split(os.sep)[0], rel, cls, ';'.join(flags), pages))
    rows.sort()
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['folder', 'file', 'class', 'signals', 'pages'])
        w.writerows(rows)
    tot = {}
    by = {}
    for folder, rel, cls, flags, pages in rows:
        tot[cls] = tot.get(cls, 0) + 1
        by.setdefault(folder, {}).setdefault(cls, 0)
        by[folder][cls] += 1
    print('overall:', {k: tot.get(k, 0) for k in ('green', 'amber', 'red', 'unknown')})
    for folder in sorted(by):
        c = by[folder]
        print(f"  {folder:28} green={c.get('green', 0):3d} amber={c.get('amber', 0):3d} red={c.get('red', 0):3d} unknown={c.get('unknown', 0):3d}")
    usaid = [r for r in rows if 'USAID' in r[3]]
    print('USAID-linked documents:', len(usaid), '| in 01_Water_Sanitation:', sum(1 for r in usaid if r[0] == '01_Water_Sanitation'))
    print('wrote', out)


if __name__ == '__main__':
    main()
