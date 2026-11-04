# Hosting the offline map files

The app downloads maps by reading **only the part it needs** from a big map file (HTTP range requests). So the map
files just need to sit on any web host that supports range requests and has no download fees. We use Cloudflare R2.

```
Protomaps public build  --(tool/pmtiles_extract.dart)-->  tile dump  --(tool/pmtiles_pack.py)-->  mid-atlantic.pmtiles
                                                                                                         |
                                                                       (tool/upload_r2.py)  <------------+
                                                                              |
                                                                    Cloudflare R2 bucket --> app reads regions from it
```

## Build a region file (done once per region, on the developer PC)

```
dart --packages=.dart_tool/package_config.json tool/pmtiles_extract.dart \
     --url https://build.protomaps.com/YYYYMMDD.pmtiles \
     --bbox "-84.45,33.7,-74.55,42.4" --minzoom 0 --maxzoom 14 --out tools/maps/mid-atlantic
python tool/pmtiles_pack.py tools/maps/mid-atlantic        # -> tools/maps/mid-atlantic.pmtiles
```

(`dart run` does not work on a PC without a C compiler, so call `dart` with `--packages` as shown.)
Check the result by extracting a small area from the packed file and comparing it, as the project did for Loudoun.

## One-time Cloudflare setup (about 10 minutes, free under 10 GB)

1. Create a free Cloudflare account and open **R2 Object Storage**. It may ask for a payment card; nothing is charged
   below 10 GB of storage.
2. **Create bucket**, for example `survival-node-maps`.
3. Make it readable by the app:
   - quick start: bucket **Settings > Public access > R2.dev subdomain > Allow**. Fine for testing.
   - for the real release: **Custom Domains > Connect domain** (a domain you own on Cloudflare). R2.dev links are
     rate limited and meant for testing only.
4. **R2 > Manage API tokens > Create API token**: permission *Object Read & Write*, limited to this bucket.
   Copy the **Account ID**, **Access Key ID** and **Secret Access Key**. The secret is shown once.
   Keep these private. Never paste them into chat, code or the repo.

## Upload

In PowerShell (the variables exist only in that window):

```
$env:R2_ACCOUNT_ID="..."; $env:R2_ACCESS_KEY_ID="..."; $env:R2_SECRET_ACCESS_KEY="..."; $env:R2_BUCKET="survival-node-maps"
python tool/upload_r2.py tools/maps/mid-atlantic.pmtiles
```

`python tool/upload_r2.py --selftest` checks the request signing without any keys or network.

## Point the app at it

Edit `assets/catalog/categories.json`, category `maps`, `mapSource.regions[0].url` to the public address, for example
`https://pub-xxxx.r2.dev/mid-atlantic.pmtiles` (or your custom domain). Rebuild the app. The app tries our hosted
region first and only falls back to the public Protomaps builds outside the regions we host.

Check it from the PC before shipping:

```
dart --packages=.dart_tool/package_config.json tool/pmtiles_extract.dart --url https://YOUR-PUBLIC-URL/mid-atlantic.pmtiles \
     --bbox "-77.7,39.05,-77.5,39.2" --minzoom 0 --maxzoom 14 --out tools/maps/check
```

## Adding or refreshing a region

Build a new `.pmtiles` from a newer Protomaps build, upload it under the same name (it replaces the old file), and
add a new entry to `regions` for each new area. OpenStreetMap changes daily; refresh a few times a year.

## Licence

Map data is OpenStreetMap (ODbL) and Natural Earth (public domain), via the Protomaps basemap. The app shows the
attribution on the Maps screen; keep it when you host the files.
