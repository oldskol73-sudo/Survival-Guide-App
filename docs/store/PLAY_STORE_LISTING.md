# Google Play listing: Blackout IQ

**DRAFT for review.** Everything here is written from what the app actually does today. Items marked **CONFIRM** need your decision or a fact only you know.

## Listing text

**App name** (30 max): `Blackout IQ: Offline Survival`

**Short description** (80 max, this is exactly 80):
`Offline survival library: manuals, maps, checklists and a locked document vault.`

**Full description** (4000 max):

```
Blackout IQ keeps practical survival knowledge on your phone, so it works when the network does not.

WHAT YOU GET
- A library of free manuals and guides on water, food, first aid, shelter, power and more. Mainly US Government publications (FEMA, CDC, NOAA, USGS, USDA, US Army) and older public-domain titles. Download the ones you want; they stay on the phone.
- Step By Step Problem Solver, Answer Questions and Priority Plan: describe your situation in plain words and get the best passages from the library, with the page to read. With an optional on-device AI model installed, answers are written out as steps.
- Offline Maps: download a map of the area around you (choose how many miles), then use it with no signal.
- Survival Kit Checklist, Gear list and a Field Guide that groups the library by topic.
- Video Tutorials: about 2,000 how-to links, filed by subject and matched to the manuals that cover the same topic. Browsing works offline; watching needs internet and opens on YouTube.
- Family: your family plan, emergency numbers for your country, gathering points, and a Documents Vault for IDs, insurance and records. The vault is encrypted on the device and opens with your fingerprint or screen lock.
- Emergency SOS: screen-flash signal and built-in emergency steps that work with no library, no model and no network.

BUILT FOR WHEN THINGS GO WRONG
- No account. No ads. No analytics. Your family details and documents never leave your phone.
- Air-gap indicator shows whether Wi-Fi, cellular and Bluetooth are off. "Sealed" mode blocks the app's own network use.

IMPORTANT
Blackout IQ is reference material. Information can be wrong, out of date or not fit your situation, and AI-written answers can contain mistakes. It is not medical, legal or professional advice, and the app cannot call or alert emergency services. In an emergency, call your local emergency number (911 in the US).

Map data (c) OpenStreetMap contributors. Video tutorials belong to their creators and play on YouTube.
```

**Category:** Education. (Books & Reference is the alternative. Avoid Health & Fitness: it brings extra health-app policy review.)

**Tags:** survival, preparedness, offline, emergency, first aid, maps, off grid.

**Contact:** publishing@twelvescentspub.com, [website](https://twelve12scents.com/), [privacy policy](https://twelve12scents.com/privacy-policy/).
## What a store user actually receives (keep the listing honest)

The app ships **without** the manuals. The catalog offers **36 downloadable items**: about 30 manuals, one Wikipedia archive entry (its download address is still a placeholder: **CONFIRM** or remove it), 1 offline-map source with 10 hosted US regions, and 4 optional AI models. The 543-document library on the developer's phone is **not** part of the app. Do not describe "hundreds of manuals" in the listing unless you decide to host more, and every hosted document needs a clear licence.

## Data safety form

Recommended answers, with reasons. **CONFIRM** the Cloudflare item before submitting.

| Question | Answer | Why |
|---|---|---|
| Does the app collect or share any of the required user data types? | **No** | Nothing is sent to us. Family details, vault photos, location and settings stay on the device. |
| Is all data encrypted in transit? | Yes | All downloads use HTTPS; cleartext traffic is disabled except the local loopback server on the phone. |
| Can users request that data be deleted? | Not applicable | We hold no user data. Uninstalling removes the on-device data. |
| Independent security review | No | |

**CONFIRM before answering "no data collected":** the map files are served from a Cloudflare R2 bucket. If you enable request logging there (Logpush or access logs) that stores IP addresses and requested files, which would need to be declared. If logging is off, "no data collected" is accurate. Downloads from archive.org, agencies and Hugging Face are made directly to those sites, not through us.

## Permission and declaration forms

| Permission | Justification to enter |
|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` | Download maps, manuals and models on request; show whether the device is air-gapped. |
| `BLUETOOTH` (API 30 and below) | Read whether Bluetooth is on, for the air-gap indicator. Never scans or connects. |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Centre an offline map download on the user's position and show the position on the map. Foreground only. Not transmitted. |
| `USE_BIOMETRIC` | Unlock the Documents Vault. |
| `POST_NOTIFICATIONS` | Show progress for large downloads. |
| `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_DATA_SYNC` | Let user-started downloads of large map and model files finish when the screen is off. Play will ask you to declare the foreground service type (data sync) and may ask for a short screen recording of the feature. |

## Other Play Console declarations

- **Ads:** No. **App access:** all features work without an account. Reviewers need a phone with a screen lock set to try the vault (**CONFIRM** what the vault does on a phone with no lock).
- **Target audience:** 18 and over is the safest choice. Not designed for children.
- **Content rating (IARC questionnaire):** answer truthfully. Reference content includes first aid and medical information, hunting and trapping, and military manuals. Expect a Teen-level rating; do not guess, run the questionnaire.
- **Health apps declaration:** read the form carefully and answer truthfully. The app gives general reference information, not diagnosis or monitoring.
- **Emergency features:** the SOS screen and Settings > About state that the app cannot call emergency services.
- **Government apps:** the app is **not** from or endorsed by any government agency. Several manuals are US Government works; the listing says "publications", never implies endorsement. Keep it that way.
- **Account deletion:** not applicable (no accounts).

## Assets checklist

| Asset | Spec | Status |
|---|---|---|
| App icon | 512 x 512 PNG | Needs to be checked: the launcher icon in the project may still be the default. **CONFIRM** |
| Feature graphic | 1024 x 500 | Not made. The Twelve Scents sunrise masthead art could be adapted. |
| Phone screenshots | 2 to 8, 16:9 or 9:16 | Not taken. Suggested: Home, Family, Library, Videos, Offline Map, Vault banner, tour page. Do not show real personal data. |
| Privacy policy URL | public page | Draft in `PRIVACY_POLICY.md`, not hosted. |
| Developer account | USD 25, one time | **CONFIRM** you have one. New personal accounts may need a closed test (a minimum number of testers for about two weeks) before production; check the current rule in Play Console. |

## Before you press publish

1. Create the upload key and build the bundle (`RELEASE_SIGNING.md`).
2. Host the privacy policy and put its address in the app and in Play Console.
3. Test on at least two more phones, one older or smaller, and one tablet if you list tablets.
4. Confirm the native libraries meet the 16 KB page-size rule for new uploads (check in Play Console's pre-launch report).
5. Replace the placeholder Wikipedia address or drop that item.
