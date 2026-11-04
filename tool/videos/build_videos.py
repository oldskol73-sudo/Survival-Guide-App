"""Builds assets/catalog/videos.json: a database of YouTube LINKS (title, channel, length, topic, library category) with
the library PDFs that cover the same subject. Nothing is downloaded from YouTube; the app opens the link in the
YouTube app or browser when the device is online and not sealed.

    python -I tool/videos/build_videos.py INDEX.db CHANNELS_DIR

INDEX.db   = desktop search index from tool/rag_eval/build_index.py (used to match videos to PDFs)
CHANNELS_DIR holds one <channel>.tsv per channel:  id <TAB> title <TAB> seconds <TAB> views <TAB> yyyymmdd
"""
import json
import os
import re
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, os.path.join(ROOT, 'tool', 'rag_eval'))
from run_eval import terms  # noqa: E402  (same stop-word list the app search uses)

CHANNELS = {  # file stem -> display name
    'thepreppingteam2937': 'The Prepping Team',
    'CityPrepping': 'City Prepping',
    'CanadianPrepper': 'Canadian Prepper',
    'leadfarmer73': 'Lead Farmer',
    'x_FEMA': 'FEMA',
}

# (library category id, topic label, regex on the lower-case title).  First match wins, so specific rules come first.
RULES = [
    ('medical', 'First aid and bleeding', r'first aid|tourniquet|bleed|wound|cpr\b|trauma|ifak|medical kit|stop the bleed'),
    ('medical', 'Illness and medicine', r'medic|antibiotic|fever|infection|sick|flu\b|covid|pandemic|vaccine|herbal|elderberry|dental|tooth|prescription|pharmac|vitamin|health'),
    ('water', 'Water storage', r'store water|water storage|water barrel|water container|stored water|water tank|\bwater\b.*(store|storage)'),
    ('water', 'Water purification', r'water filter|purif|boil|distill|sawyer|berkey|lifestraw|well water|rain ?water|rain barrel|cistern|water (source|treatment|supply)|safe water|drinking water|\bwater\b'),
    ('food', 'Canning and preserving', r'\bcan(ning|ned)?\b|pressure canner|preserv|dehydrat|freeze.?dr|jerky|pickl|ferment|root cellar|smok(e|ing) meat|cure|vacuum seal|mylar|oxygen absorber'),
    ('food', 'Food storage and cooking', r'food storage|stockpile|pantry|long.?term food|\bfood\b|rice|beans|flour|bread|recipe|cook|meal|grocery|eat |sourdough|bake|baking|honey|salt\b|sugar|canned'),
    ('food', 'Gardening and growing', r'garden|seed|planting|planter|plants|grow|soil|compost|greenhouse|harvest|orchard|fruit tree|peach|strawberr|potato|tomato|vegetable|raised bed|permaculture|mulch|pollinat|\bbees?\b|honeybee'),
    ('food', 'Livestock and hunting', r'chicken|chick|egg|rabbit|goat|pig|cattle|cow\b|livestock|incubator|hunt|trap|snare|fish|butcher|slaughter|hog|turkey|duck|quail|homestead'),
    ('energy', 'Power and solar', r'solar|battery|batteries|generator|power station|power bank|inverter|off.?grid power|backup power|ecoflow|bluetti|jackery|lithium|lifepo4 down|power outage|blackout|wind turbine|ev\b|charging'),
    ('energy', 'Heating and cooking fuel', r'heater|kerosene|propane|wood stove|rocket stove|fire ?wood|firewood|stove|fuel|heat(ing)?\b|candle|lantern|lamp|light(s|ing)?\b|flashlight|headlamp'),
    ('comms', 'Radio and communication', r'radio|ham\b|gmrs|cb\b|baofeng|antenna|walkie|comms?\b|communicat|meshtastic|emp\b|faraday|signal|scanner|frequency'),
    ('comms', 'Navigation', r'map\b|maps\b|compass|navigat|gps|topo|land nav|orienteer'),
    ('transport', 'Vehicles and bug out', r'vehicle|truck|\bcar\b|car kit|jeep|bug out vehicle|tire|engine|diesel|gas tank|fuel stabil|trailer|atv|bike|bicycle|gear for your car|get home bag'),
    ('mechanical', 'Tools and repair', r'tool|repair|fix\b|build|diy|chainsaw|saw\b|axe\b|hatchet|knife|knives|sharpen|multi.?tool|welder|weld|drill|workshop|plumb|pump|well pump|hand pump'),
    ('carpentry', 'Shelter and building', r'shelter|tarp|tent|cabin|build(ing)? (a|your)|shed|lumber|wood ?working|roof|insulat|log home|tiny house|container home|barn|fence|fencing|gate\b'),
    ('longterm', 'Security and safety', r'security|defen[cs]e|gray man|home protection|situational|threat|looter|safe room|intruder|self.?protection'),
    ('longterm', 'Bug out and go bags', r'bug.?out|bob\b|go bag|get home bag|72.?hour|ever(yday)? carry|edc|survival kit|emergency kit|prepper pack|backpack|\bpack\b|bag\b'),
    ('longterm', 'Disasters and emergencies', r'hurricane|tornado|earthquake|flood|wildfire|storm|blizzard|winter storm|heat wave|disaster|evacuat|emergency|shelter in place|ice storm|nuclear|fallout|radiation|emp|solar flare|war\b'),
    ('longterm', 'Prepping basics', r'prep(ping|per|ared|are)?\b|survival|bushcraft|self.?reliance|self.?sufficien|homestead|off.?grid|checklist|supplies|stockpil'),
]
RULES = [(c, t, re.compile(r)) for c, t, r in RULES]

SKIP = re.compile(r'q&a|live ?chat|livestream|live stream|\blive\b|podcast|giveaway|shoutout|channel update|trailer|merch|announcement|#shorts|collab\b|reaction|unboxing haul|membership|russia|putin|nato|china|chinese|north korea|iran|israel|ukraine|breaking|alert!|trump|biden|election|nuke sub|war measures|fema go|grant|operations center|amendment|program|policy|nbeoc|ww3|ww 3|wwiii|world war|nasa|dam destroyed|update!|breaking|webinar|public comment|framework|press conference|briefing|accessible|town hall|ask the expert|nofo|funding', re.I)


HOWTO = re.compile(r'how|tips?|guide|build|make|diy|learn|prepare|checklist|kit|items|things|lessons?|steps?|beginner|basics|what to|best|vs\.?|review|test|install|store|use|plan')


def classify(title):
    t = title.lower()
    if SKIP.search(t):
        return None
    for cat, topic, rx in RULES:
        if rx.search(t):
            # the catch-all preparedness bucket only keeps titles that teach or explain something
            if cat == 'longterm' and not HOWTO.search(t):
                return None
            return cat, topic
    return None


def fnv_rel(rel):  # not needed by the app (links use paths) but handy for debugging
    return rel


GENERIC = set("""guide manual manuals handbook basics basic complete practical how best top ways things thing tips tip tutorial
video part series new old home emergency survival prepper prepping prep list guide fm tm tc usda army us military
before after during end start started ways year years every worst top first last three four five six seven eight nine ten hack hacks
wish know knew need needs will want wont dont cant just really actually everything anything something nothing industry industrial
build building built electric survive survivor surviving survival disaster disasters prepare prepared preparing preparedness items kit bunker underground storm inflation economy price prices
simple easy cheap free big small little full short long great good bad real real life work works working run running""".split())

# (regex on the video title, regex on the document title).  Curated so a video about a subject links to the manuals on it.
THEMES = [(re.compile(v, re.I), re.compile(d, re.I)) for v, d in [
    (r'water (filter|purif|treat)|purif|boil(ing)? water|berkey|sawyer|lifestraw|clean water|drinking water|murky water', r'water (treatment|filter|purif|disinfect)|disinfect|filtration|chlorin|silver clay|slow sand|emergency water'),
    (r'water (storage|barrel|container|tank)|store water|stored water', r'water storage|storage tank|waterfaq|emergency water'),
    (r'rain ?water|rain barrel|catchment|cistern', r'rainwater|catchment|cistern'),
    (r'well|hand pump|water pump', r'well|pump'),
    (r'latrine|toilet|sanitation|hygiene|sewage|septic', r'latrine|sanitation|hygiene|arborloo|toilet'),
    (r'first aid|tourniquet|bleed|wound|cpr|trauma|ifak', r'first aid|tc 4-02|wound|survival and austere'),
    (r'burn|hypotherm|frostbite|heat stroke|choking|heimlich', r'first aid|survival and austere|fm 21-11'),
    (r'herb|natural remed|medicinal|elderberry|tincture', r'herb|medicin|remed'),
    (r'can(ning)?|pressure canner|water bath', r'canning'),
    (r'dehydrat|jerky|drying|freeze.?dr', r'dry|dehydrat|jerky|drying'),
    (r'vacuum seal|mylar|oxygen absorber|food storage|stockpile|pantry', r'food storage|storage tips|vacuum packing'),
    (r'garden|seed|planting|vegetable|greenhouse|compost|raised bed|soil|harvest', r'garden|seed|greenhouse|compost|vegetable|growing'),
    (r'bees?|beekeep|honey', r'bee|honey'),
    (r'chicken|poultry|eggs?|duck|quail', r'chicken|poultry|egg'),
    (r'rabbit|goat|livestock|cattle|pigs?|hogs?', r'rabbit|goat|livestock|animal'),
    (r'hunt|trap|snare|fishing|butcher|slaughter', r'game|hunt|trap|fish|butcher|fm 21-76'),
    (r'solar', r'solar|photovolt|pv'),
    (r'wind (turbine|power)', r'wind'),
    (r'generator|inverter|battery|batteries|power station', r'generator|inverter|battery'),
    (r'wood stove|rocket stove|heater|heating|firewood|chimney', r'stove|rocket|heat|chimney'),
    (r'radio|ham|gmrs|cb|antenna|baofeng|meshtastic|faraday|emp', r'radio|antenna|crystal|sincgars|communications'),
    (r'maps?|compass|navigat', r'map|compass|navigation|land nav'),
    (r'knot|rope|cordage', r'knot|rope|cordage'),
    (r'shelter|tarp|tent|cabin|lean.?to', r'shelter|cabin|fm 5-426|carpentry'),
    (r'earthquake', r'earthquake|putting down roots'),
    (r'tornado', r'tornado'),
    (r'wildfire', r'wildfire'),
    (r'heat wave|extreme heat', r'extreme heat'),
    (r'hurricane|flood|winter storm|blizzard|disaster plan|evacuat', r'are you ready'),
    (r'pets?|dogs?', r'pet'),
    (r'nuclear|fallout|radiation', r'atomic|fallout|nuclear'),
    (r'blacksmith|forge|anvil|scrounging', r'blacksmith|forge|scounging|scrounging'),
    (r'vehicle|truck|engine|car|diesel', r'automotive|engine|tm 9'),
    (r'soap|lye', r'soap'),
    (r'sharpen|axe|saw|knife|knives', r'sharpen|axe|saw|farm shop'),
    (r'bug.?out|go bag|get home bag|bob|survival kit', r'bug ?out|camp equipment|fm 21-76'),
]]


def stem(w):
    for suf in ('ing', 'ies', 'es', 'ed', 's'):
        if w.endswith(suf) and len(w) - len(suf) >= 4:
            return w[:-len(suf)]
    return w


def load_docs(db):
    docs = []
    for rel, title, cat in db.execute('SELECT rel_path, title, category FROM documents'):
        words = {stem(w) for w in terms(title) if w not in GENERIC and not w.isdigit()}
        docs.append((rel.replace(chr(92), '/'), title, cat, words))
    df = {}
    for _, _, _, ws in docs:
        for w in ws:
            df[w] = df.get(w, 0) + 1
    return docs, df


def link_pdfs(docs, df, title, category):
    """Up to two library documents whose TITLE shares the video's subject words (two shared words, or one rare word)."""
    vw = {stem(w) for w in terms(title) if w not in GENERIC and not w.isdigit()}
    if not vw:
        return []
    scored = []
    for rel, dt, dc, ws in docs:
        if category != 'longterm' and dc not in (category, 'longterm'):
            continue
        shared = vw & ws
        if not shared:
            continue
        rare = [w for w in shared if df.get(w, 0) <= 2 and len(w) >= 7] if len(ws) <= 2 else []
        if (len(shared) >= 2 and sum(len(w) >= 5 for w in shared) >= 2) or rare:
            score = sum(1.0 / df.get(w, 1) for w in shared) + len(shared)
            scored.append((score, rel, dt))
    scored.sort(reverse=True)
    picked = {rel: dt for _, rel, dt in scored[:2]}
    for vrx, drx in THEMES:
        if vrx.search(title):
            cands = [(len(dt), rel, dt) for rel, dt, dc, ws in docs if drx.search(dt) and dc in (category, 'longterm', 'medical', 'water', 'food', 'energy', 'comms')]
            # prefer documents whose title also shares words with the video, then shorter (more focused) titles
            cands.sort(key=lambda c: (-len({stem(w) for w in terms(c[2])} & vw), c[0]))
            for _, rel, dt in cands[:2]:
                picked.setdefault(rel, dt)
            break
    return [{'path': rel, 'title': dt} for rel, dt in list(picked.items())[:3]]


def main():
    dbp, chdir = sys.argv[1], sys.argv[2]
    db = sqlite3.connect(dbp)
    docs, df = load_docs(db)
    out, seen = [], set()
    stats = {}
    for stem, name in CHANNELS.items():
        p = os.path.join(chdir, stem + '.u8.tsv')
        if not os.path.exists(p):
            print('missing', p)
            continue
        n_in = n_kept = n_linked = 0
        for line in open(p, encoding='utf-8'):
            parts = line.rstrip('\n').split('\t')
            if len(parts) < 3 or not parts[0] or parts[0] in seen:
                continue
            vid, title = parts[0], parts[1].strip()
            n_in += 1
            try:
                secs = int(float(parts[2]))
            except ValueError:
                secs = 0
            if secs and secs < 90:  # shorts and clips
                continue
            c = classify(title)
            if not c:
                continue
            cat, topic = c
            seen.add(vid)
            pdfs = link_pdfs(docs, df, title, cat)
            n_kept += 1
            n_linked += bool(pdfs)
            row = {'id': vid, 'title': title, 'channel': name, 'cat': cat, 'topic': topic, 'secs': secs}
            if pdfs:
                row['pdfs'] = pdfs
            out.append(row)
        stats[name] = (n_in, n_kept, n_linked)
    out.sort(key=lambda r: (r['cat'], r['topic'], r['title'].lower()))
    dest = os.path.join(ROOT, 'assets', 'catalog', 'videos.json')
    with open(dest, 'w', encoding='utf-8') as f:
        json.dump({'schemaVersion': 1, 'note': 'Links only. Videos belong to their creators and play on YouTube.', 'videos': out},
                  f, ensure_ascii=False, separators=(',', ':'))
    for k, (a, b, c) in stats.items():
        print(f'{k:22} listed {a:5d}  kept {b:5d}  linked to a PDF {c:5d}')
    print('total videos', len(out), '| with PDFs', sum(1 for r in out if 'pdfs' in r), '|', os.path.getsize(dest) // 1024, 'KB')


if __name__ == '__main__':
    main()
