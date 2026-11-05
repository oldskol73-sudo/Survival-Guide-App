# Android release signing and the app bundle

Google Play needs an Android App Bundle (`.aab`) signed with an **upload key** that only you hold. Play then re-signs what users download with its own key (Play App Signing).

## What is already set up

- `android/app/build.gradle.kts` signs release builds from `android/key.properties` **if that file exists**. Without it, the build falls back to the debug key so local builds keep working. A bundle signed with the debug key will be rejected by Play.
- `.gitignore` blocks `*.jks`, `*.keystore`, `*.p12` and `android/key.properties`, so the key cannot be committed by accident.

## One-time: create the upload key

On this PC, in PowerShell, from the project folder:

```
powershell -ExecutionPolicy Bypass -File tool\make_upload_key.ps1
```

It asks you to choose a password (typed on screen, never stored in the repo or in chat), creates `survival-node-upload.jks` in `%USERPROFILE%\survival-node-keys\`, and writes `android\key.properties` pointing at it.

**Back up the `.jks` file and the password now**, in two places (for example a password manager and an encrypted USB drive). If the upload key is lost you can ask Play to reset it, but that takes days. Never email it or put it in cloud notes in plain form.

## Build the bundle

```
flutter build appbundle --release --target-platform android-arm64
```

Output: `build\app\outputs\bundle\release\app-release.aab`. Before each upload, raise the number after `+` in `version:` in `pubspec.yaml` (for example `1.0.0+2`); Play rejects a repeated build number.

## Check the signature

```
keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

The owner shown should be the one you entered when creating the key, not "Android Debug".

## Good to know

- The app is arm64-only. Play accepts this (64-bit is required), but the app will not install on 32-bit-only or x86 devices, including most emulators.
- Test the **release** build, not only debug, before uploading: install the `.apk` from `flutter build apk --release` on a phone and walk the main screens.
- Enrol in Play App Signing when Play Console asks (accept the default).
