# Blackout IQ: Griddown Resilience: release notes

Version 1.0.0 (version code 4). First test release. Package: com.twelvescentspub.blackoutiq.

## Play Console "What's new" (limit 500 characters; paste this)

```
First test release of Blackout IQ: Griddown Resilience.
New: Wild Medicinal Plants section with seven public-domain botanical references (colour plates, poisonous-plant guides, safety warnings), downloaded one at a time and read offline.
Also new: the app now asks to show download notifications, Library categories start switched off so you sync only what you pick, plus the new name, tagline and app ID.
Tell us what is confusing or broken. Thank you for testing.
```

(About 380 characters.)

## Release letter (email or post to testers)

**Subject:** Blackout IQ test build 1.0.0 (4): what is new

Hello testers,

Thank you for helping test Blackout IQ: Griddown Resilience. *Knowledge When Everything Goes Dark.* Here is what is in this build and what to try.

**What is new**

- **Wild Medicinal Plants (Library).** Seven public-domain references you download one at a time and read offline:
  - Millspaugh, *Medicinal Plants*, volumes 1 and 2 (1892): 180 colour plates with names, range, history, uses and poisoning effects.
  - Henkel, *Wild Medicinal Plants of the US* (USDA, 1906): common and scientific names, habit, range and parts used.
  - Henkel, *Weeds Used in Medicine* (USDA, 1904).
  - Chesnut, *Thirty Poisonous Plants of the US* (USDA, 1898): where each grows, which parts poison, what the effects are.
  - Marsh, *Stock-Poisoning Plants of the Range* (USDA, 1924).
  - Densmore, *Uses of Plants by the Chippewa Indians* (Smithsonian, 1928).
  - Every title is a US Government publication or was published before 1926. Start with the poisonous-plant guides.
  - A warning sits at the top of the screen. These books are historical. They are not a safe way to identify, eat or medicate with a wild plant, and they are not medical advice.
  - Nothing is bundled. The books total about 107 MB, so use Wi-Fi.
- **Download notifications.** The app now asks permission to show download progress. Allow it to see progress in the notification shade. Downloads still work if you decline.
- **Library categories start off.** Nothing syncs by default. Switch on the categories you want, then tap **Sync selected categories**.
- **New name and tagline.** The app is now Blackout IQ: Griddown Resilience, with the tagline *Knowledge When Everything Goes Dark.* The Home header, About screen, tour and Play listing all use it.
- **New app ID.** The app ID is now `com.twelvescentspub.blackoutiq`. This is a separate app from any earlier "Survival Node" build, so it installs next to it and starts empty.
- **Updated first-launch tour.** The welcome and tiles pictures were retaken from the real app and show the new name.
- **Home screen fix.** The Library tile artwork now lines up with the other five tiles.

**What is unchanged**

Offline manuals and guides, offline maps, Survival Kit Checklist, Step By Step Problem Solver, Family plan, encrypted Documents Vault, Videos, My Documents. No account, no ads, no tracking. Nothing you enter leaves your phone.

**Please try**

1. Library, then Wild Medicinal Plants. Read the warning, download one book, turn on Airplane Mode and open it.
2. Check that the Home tiles look even and the title reads correctly.
3. Walk through the first-launch tour and check the pictures show the new name.

**Known limits**

- The plant pictures are 1890s to 1920s colour plates and line drawings. There are no modern photographs.
- Plant doses and remedies in the books are out of date and some are unsafe.
- Videos play through YouTube and need internet.

**If the download does not start:** search Google or the Play Store for `com.twelvescentspub.blackoutiq`, and make sure the Play Store is signed in with the Google account you gave me. A new release can take up to an hour to appear.

Please stay opted in until I tell you the test is finished. Reply with what you were doing, what you expected and what happened. A screenshot helps.

Thank you,
Twelve Scents Publishing

---

## Change log (developer)

| Version code | Changes |
|---|---|
| 4 | Notification permission requested before the first download (Android 13+). All Library categories start off; the Sync button waits until one is on. |
| 3 | Home: Library tile artwork aligned with the other tiles. |
| 2 | Tour: welcome and tiles pictures retaken with the Blackout IQ name. |
| 1 | Wild Medicinal Plants section (seven public-domain references, safety notice, Library entry, catalog category `plants`). Title and tagline rollout. Android application id changed to `com.twelvescentspub.blackoutiq`. |

Earlier groundwork (store documents, privacy policy, launcher icon, signing, licence audit, My Documents, maps, Videos, Family tab) is in the git history.
