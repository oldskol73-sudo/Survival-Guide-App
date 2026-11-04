#!/bin/bash
# Builds the US regional .pmtiles files (street detail, zoom 0-14) into tools/maps/. Sequential; safe to re-run
# (regions already packed are skipped). Needs: Flutter's dart on PATH, python. Upload afterwards with tool/upload_r2.py.
cd "$(dirname "$0")/.." || exit 1
export PATH="$PATH:/c/Users/kjord/flutter/flutter/bin"
BUILD=${1:-$(date -u +%Y%m%d)}
URL=https://build.protomaps.com/$BUILD.pmtiles
# id|west,south,east,north
REGIONS="
northeast|-80.6,40.4,-66.9,47.5
southeast|-91.7,24.4,-79.9,35.2
midwest|-97.3,36.4,-80.5,49.4
south-central|-106.7,25.8,-88.9,37.1
mountain|-117.1,31.3,-102.0,49.1
west|-124.8,32.5,-114.0,49.1
alaska-south|-170.0,51.0,-129.0,61.5
alaska-north|-170.0,61.5,-129.0,71.6
hawaii|-160.4,18.8,-154.7,22.3
"
for r in $REGIONS; do
  id=${r%%|*}; bbox=${r##*|}
  if [ -s tools/maps/$id.pmtiles ]; then echo "skip $id (done)"; continue; fi
  echo "=== $id  $bbox  $(date)"
  rm -f tools/maps/$id.tiles tools/maps/$id.json
  dart --packages=.dart_tool/package_config.json tool/pmtiles_extract.dart --url "$URL" --bbox "$bbox" --minzoom 0 --maxzoom 14 --out tools/maps/$id 2>&1 | tail -3 \
    && python tool/pmtiles_pack.py tools/maps/$id 2>&1 | tail -2 \
    && rm -f tools/maps/$id.tiles
  ls -l tools/maps/$id.pmtiles
done
echo "ALL DONE $(date)"
