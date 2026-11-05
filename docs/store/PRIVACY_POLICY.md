# Survival Node: Privacy Policy

**DRAFT for review.** Fill in the three `[...]` placeholders, have it read by whoever advises you on legal matters, host it at a public web address, and put that address in `lib/ui/about_screen.dart` (`kPrivacyPolicyUrl`) and in both store listings.

- Publisher: Twelve Scents Publishing
- Contact: [support email address]
- Effective date: [date]

## The short version

Survival Node has no accounts, no advertising, no analytics and no tracking. The information you enter, your photos of documents, your family details, your checklist and your settings stay on your device. We do not receive any of it, and we cannot read it.

## What stays on your device

| What | Where it lives | Who can see it |
|---|---|---|
| Family members, emergency contacts and gathering points you type in | A small file in the app's private storage | Only you |
| Documents Vault photos and notes | Encrypted (AES-256-GCM) in the app's private storage. The key sits in the system secure store (Android Keystore / iOS Keychain). Opening the vault needs your fingerprint, face or screen lock. | Only you |
| Survival checklist, settings, search index | The app's private storage | Only you |
| Your location | Read by the phone only to pick the centre of an offline map download and to show your position on the map. It is not stored by us and never sent to us. | Only you |
| Camera and photo choices | Used only to add a picture of a document to the vault | Only you |

Uninstalling the app deletes all of this. We cannot recover it, because we never had it.

## When the app uses the internet

The app connects to the internet only when you ask it to:

- **Downloading maps, manuals or AI models.** The files come from servers run by us (for maps) or by public archives and agencies (for manuals and models), such as archive.org, FEMA, NOAA, USGS, USDA, the US Army publishing sites, the Wikipedia/Kiwix project and Hugging Face. Any server you download from can see your IP address and which file you asked for. For a map download it can also see which map tiles you requested, which reveals the area. We do not link this to you. The map files are hosted on Cloudflare R2 [confirm: no request logging is enabled on the bucket].
- **Playing a video.** The Videos tab lists links. Tapping Watch opens the video in the YouTube app or your browser, and YouTube's own privacy policy then applies. The app does not embed YouTube, load any Google code, or download videos.
- **Checking the radios.** The app reads whether Wi-Fi, cellular and Bluetooth are on, to show the air-gap indicator. It does not scan for or connect to any device or network.

When you turn on "sealed" mode, the app blocks its own network use entirely.

## What we do not do

- We do not sell or share personal information, because we do not collect any.
- We do not use advertising identifiers, and the app contains no advertising or analytics code.
- We do not knowingly collect information from children. The app is not designed for children.

## Permissions the app asks for, and why

- **Location:** choose and centre an offline map area, show your position on the map.
- **Camera / photos:** add a photo of a document to the vault.
- **Biometrics / screen lock:** unlock the vault.
- **Notifications and background activity:** show progress for large downloads and let them finish when the screen is off.
- **Bluetooth, Wi-Fi and network state:** show whether the device is air-gapped (read-only status).

## Safety notice

The library, checklists and any AI-written answers are reference material. They can be wrong or out of date. They are not medical, legal or professional advice, and the app cannot call or alert emergency services. In an emergency, call your local emergency number.

## Third-party material

Maps use OpenStreetMap data (ODbL). Manuals are mainly US Government works and older public-domain publications. Video tutorials belong to their creators. Credits are listed in the app under Settings, About, safety and credits.

## Changes and contact

If this policy changes in a way that matters, the new version will be published at the same address with a new effective date. Questions: [support email address].
