// About, safety and credits: what the app is and is not, what leaves the device, and who made the material in it.
// Store reviewers and users both look for this screen, so keep it factual and in step with docs/store/PRIVACY_POLICY.md.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

/// Public address of the hosted privacy policy. Fill this in before release; the button hides while it is empty.
const kPrivacyPolicyUrl = '';

/// Shown on this screen. Keep in step with `version:` in pubspec.yaml.
const kAppVersionLabel = 'Version 1.0.0';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const h = TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.accent);
    const body = TextStyle(fontSize: 15, height: 1.45);
    Widget bullet(String t) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 2, right: 10), child: Icon(Icons.circle, size: 7, color: AppTheme.accent)),
            Expanded(child: Text(t, style: body)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('About, safety and credits')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
        const Text('Survival Node', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const Text('Published by Twelve Scents Publishing', style: TextStyle(color: AppTheme.muted)),
        const Text(kAppVersionLabel, style: TextStyle(color: AppTheme.muted)),
        const SizedBox(height: 22),
        const Text('Read this first', style: h),
        bullet('In an emergency, call your local emergency number (911 in the US). This app cannot call, text or send your location to anyone.'),
        bullet('The manuals and any AI answers are reference material. They can be wrong, out of date, or not fit your situation. They are not medical, legal or professional advice. Check the cited page and get professional help when you can.'),
        bullet('The air-gap indicator reports what your phone tells the app. Confirm Airplane Mode yourself when it matters.'),
        const SizedBox(height: 22),
        const Text('Your privacy', style: h),
        bullet('No account, no ads, no analytics and no tracking. Your family details, documents vault, checklist and settings stay on this device.'),
        bullet('The internet is used only when you choose: downloading maps, manuals or AI models, or opening a video on YouTube. Like any download, this shows your network address, and a map download shows the area you asked for, to the server that hosts the file.'),
        bullet('Your location is read on the phone only, to choose a map area. It is never sent to us.'),
        bullet('Documents you put in the vault are encrypted on the device and locked behind your fingerprint or screen lock.'),
        const SizedBox(height: 22),
        const Text('Sources and credits', style: h),
        bullet('Map data © OpenStreetMap contributors (ODbL), Natural Earth (public domain), and the Protomaps basemap. Maps are drawn with MapLibre.'),
        bullet('Manuals and guides in the catalog are mainly US Government works from FEMA, CDC, NOAA, USGS, USDA and the US Army, plus archive copies of older public-domain publications. Each item lists its own licence in the Library.'),
        bullet('Wikipedia articles, if you download them through Kiwix, are © Wikipedia contributors under CC BY-SA 4.0.'),
        bullet('On-device AI models, if you install them: Llama 3.2 (Built with Llama, under the Llama 3.2 Community License), Qwen2.5 (Apache 2.0) and all-MiniLM-L6-v2 (Apache 2.0).'),
        bullet('Video tutorials belong to their creators and play on YouTube. The list links to videos from The Prepping Team, City Prepping, Canadian Prepper, Lead Farmer and FEMA. Nothing is copied or downloaded.'),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => showLicensePage(context: context, applicationName: 'Survival Node', applicationVersion: kAppVersionLabel.replaceFirst('Version ', '')),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Open-source licences'),
        ),
        if (kPrivacyPolicyUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(kPrivacyPolicyUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.privacy_tip_outlined),
            label: const Text('Privacy policy'),
          ),
        ],
      ]),
    );
  }
}
