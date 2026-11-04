"""Scores retrieval for every scenario in scenarios.py against a desktop index built by build_index.py.

    python -I tool/rag_eval/run_eval.py INDEX.db [--mode old|new] [--show-fails] [--csv out.csv]

old = the app's keyword search as shipped (every typed word joined with AND; vector search needs a downloaded model).
new = natural-language retrieval: stop words dropped, AND of the content words first, then OR ranked by relevance,
      and a whole-library fallback when the chosen area has nothing.
A scenario PASSES when at least two of its expected words (one if it has fewer than 3) appear on the top 3 pages (the pages the pipeline would
quote). This checks that the right material is found, not the wording of an AI answer.
"""
import csv
import os
import re
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(__file__))
from scenarios import S  # noqa: E402

STOP = set("""a an the and or but if then so of to in on at by for with from as is are was were be been being am do does did
doing have has had having i me my mine we us our you your he she it its they them their this that these those there here
what which who whom whose when where why how can could should would will shall may might must not no nor too very just
about into over under up down out off again also than too any some such only own same both each few more most other
get got make made need needs want wants like use using used please help one two""".split())

ALIASES = {  # everyday words people use -> words manuals use
    "boil": "boil", "cant": "cannot",
}


def terms(text):
    out = []
    for w in re.findall(r"[A-Za-z0-9][A-Za-z0-9'-]*", text.lower()):
        w = w.replace("'", "")
        if w in STOP or len(w) < 2:
            continue
        out.append(w)
    return list(dict.fromkeys(out))


def old_query(text):
    # FtsQuery.build: every token a quoted operand, adjacency = AND
    toks = [t for t in re.findall(r'[^\s()"]+', text)]
    q = []
    for t in toks:
        t = t.replace('"', '""').replace("*", "")
        if t.upper() in ("AND", "OR", "NOT") or not t.strip("-"):
            continue
        q.append('"%s"' % t.lstrip("-"))
    return " ".join(q)


def run(db, match, category, limit=3):
    sql = "SELECT page, title, category, body FROM pages_fts WHERE pages_fts MATCH ?"
    args = [match]
    if category:
        sql += " AND category = ?"
        args.append(category)
    sql += " ORDER BY bm25(pages_fts, 1.0, 6.0) LIMIT ?"
    args.append(limit)
    try:
        return db.execute(sql, args).fetchall()
    except sqlite3.OperationalError:
        return []


def retrieve_old(db, text, category):
    return run(db, old_query(text), category)


def retrieve_new(db, text, category):
    ts = terms(text)
    if not ts:
        return []
    for cat in ([category, None] if category else [None]):
        # 1. every content word
        rows = run(db, " ".join('"%s"' % t for t in ts), cat)
        if len(rows) >= 3:
            return rows
        best = rows
        # 2. all but the last-resort words: any of them, best match first
        rows = run(db, " OR ".join('"%s"' % t for t in ts), cat)
        if rows:
            return rows if len(rows) >= len(best) else best
    return []


def main():
    args = sys.argv[1:]
    dbp = args[0]
    mode = args[args.index("--mode") + 1] if "--mode" in args else "new"
    db = sqlite3.connect(dbp)
    fn = retrieve_new if mode == "new" else retrieve_old
    rows_out, tot = [], {}
    for screen, area, text, have, expect in S:
        res = fn(db, text, area)
        hay = " ".join(r[3].lower() for r in res)
        hits = {e for e in expect if e in hay}
        # strict: the top pages must contain at least two different expected words (one if the list is short)
        ok = len(hits) >= (2 if len(expect) >= 3 else 1)
        t = tot.setdefault(screen, [0, 0, 0])
        t[0] += 1
        t[1] += ok
        t[2] += (len(res) == 0)
        rows_out.append((screen, area or "", text, "PASS" if ok else ("NONE" if not res else "WRONG"),
                         "; ".join(f"{r[1]} p{r[0]}" for r in res)))
    print(f"mode={mode}   scenarios={len(S)}")
    allp = sum(v[1] for v in tot.values())
    print(f"{'screen':8} {'n':>4} {'found':>6} {'pass%':>6} {'no results':>10}")
    for k, v in tot.items():
        print(f"{k:8} {v[0]:4d} {v[1]:6d} {100 * v[1] / v[0]:5.0f}% {v[2]:10d}")
    print(f"{'ALL':8} {len(S):4d} {allp:6d} {100 * allp / len(S):5.0f}% {sum(v[2] for v in tot.values()):10d}")
    if "--show-fails" in args:
        for r in rows_out:
            if r[3] != "PASS":
                print(f"  [{r[3]}] {r[0]}/{r[1] or '-'}: {r[2]}  ->  {r[4][:110]}")
    if "--csv" in args:
        with open(args[args.index("--csv") + 1], "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["screen", "area", "scenario", "result", "top pages"])
            w.writerows(rows_out)


if __name__ == "__main__":
    main()
