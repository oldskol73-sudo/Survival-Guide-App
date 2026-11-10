# Apple App Store notes: Blackout IQ

**DRAFT for review.** iOS cannot be built on the Windows PC. You need a Mac with Xcode (or a cloud Mac build service such as Codemagic or GitHub Actions macOS runners) and an Apple Developer Program membership (USD 99 a year).

## Already done in the project

- `ios/Runner/Info.plist` now carries the permission texts that used to sit in a side file: camera, photo library, Face ID, location when in use, Bluetooth (status only), local networking for the on-device map server, Files-app sharing, and the background download modes.
- Display name is "Blackout IQ".

## Still to do on a Mac

1. Open `ios/Runner.xcworkspace`, set the signing team and the bundle identifier (the Android id is `com.twelvescentspub.blackoutiq`; pick the iOS one and keep it).
2. On-device AI: llama.cpp (release b12224, checksum-pinned in `ios/LocalAI/Package.swift`) and the app's `native/llama_shim` bridge are built into the iOS app, which needs iOS 16.4 or later. The language model (Qwen2.5-1.5B) is downloaded by the user and is not bundled. The engine has no iOS Simulator build, so it runs on a real iPhone only. sqlite-vec (semantic search) and the ZIM reader are not built for iOS yet; search falls back to keywords.
3. Add the app icon set and launch screen artwork.
4. `flutter build ipa --release`, upload with Transporter, test through TestFlight.

## App Privacy ("nutrition label") answers

Same reasoning as the Play Data Safety form: **Data Not Collected.** Nothing is sent to us. Confirm the Cloudflare logging point in `PLAY_STORE_LISTING.md` first.

## Export compliance

The app uses standard, published encryption (AES-GCM for the vault, HTTPS for downloads) and nothing proprietary. That normally qualifies for the standard-encryption exemption, but **answer the questionnaire yourself and confirm**. Only then add `ITSAppUsesNonExemptEncryption` to the plist, so the question stops being asked on every upload.

## Notes to give App Review

- No account or login. All features work without one.
- The app is an offline reference library. It cannot place calls or contact emergency services; the SOS screen says so and tells the user to call their local number.
- Medical and survival information is reference material with a notice on every answer screen and in Settings > About, safety and credits (guideline 1.4.1).
- Background modes `fetch` and `processing` are used only to finish large user-started downloads (maps and optional models).
- The air-gap indicator only reads whether Wi-Fi, cellular and Bluetooth are on. Bluetooth is read, never scanned.
- Video links open in YouTube; no video is downloaded or embedded.
- Location is used on the device only, to choose a map area.

## Things App Review often asks about for an app like this

- Emergency or SOS wording that implies it contacts help (it does not, and says so).
- Medical claims (none are made; sources are shown).
- Third-party content rights (maps ODbL, US Government works, public-domain titles; videos are links only).
- Government look-alike. The listing must not suggest endorsement by FEMA, CDC or any agency.
