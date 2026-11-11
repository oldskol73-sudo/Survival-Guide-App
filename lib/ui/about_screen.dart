// About, safety and credits: what the app is and is not, what leaves the device, and who made the material in it.
// Store reviewers and users both look for this screen, so keep it factual and in step with docs/store/PRIVACY_POLICY.md.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import 'source_link.dart';

/// Public address of the hosted privacy policy. Fill this in before release; the button hides while it is empty.
const kPrivacyPolicyUrl = 'https://twelve12scents.com/privacy-policy/';

/// Shown on this screen. Keep in step with `version:` in pubspec.yaml.
const kAppVersionLabel = 'Version 1.0.0';

/// Current official versions of the government material in the library: (what, address). Where an agency has replaced
/// a manual, this points at the replacement. Keep in step with the store listing and with sourceUrl in categories.json.
const _govSources = <(String, String)>[
  ('Ready.gov: Are You Ready? citizen preparedness guide (FEMA)', 'https://www.ready.gov/collection/are-you-ready'),
  ('Ready.gov: Wildfires', 'https://www.ready.gov/wildfires'),
  ('Ready.gov: Extreme Heat', 'https://www.ready.gov/heat'),
  ('Ready.gov: Pets', 'https://www.ready.gov/pets'),
  ('EPA: Emergency Disinfection of Drinking Water', 'https://www.epa.gov/ground-water-and-drinking-water/emergency-disinfection-drinking-water'),
  ('CDC: Emergency Wound Care After a Natural Disaster', 'https://www.cdc.gov/disasters/hurricanes/pdf/woundcare.pdf'),
  ('CDC: Emergency wound management (archive)', 'https://archive.cdc.gov/www_cdc_gov/disasters/management.html'),
  ('NOAA National Weather Service: Tornado Safety', 'https://www.weather.gov/safety/tornado'),
  ('USGS: Putting Down Roots in Earthquake Country', 'https://pubs.usgs.gov/gip/2005/15/'),
  ('USDA / NCHFP: Complete Guide to Home Canning (NAL)', 'https://www.nal.usda.gov/research-tools/food-safety-research-projects/national-center-home-food-processing-and-preservation'),
  ('USDA National Agricultural Library', 'https://www.nal.usda.gov/'),
  ('Army: ATP 4-02.11 First Aid (replaces FM 4-25.11, FM 21-11, TC 4-02.1)', 'https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN46159-ATP_4-02.11-000-WEB-1.pdf'),
  ('Army: TC 4-02.3 Field Hygiene and Sanitation (replaces FM 21-10)', 'https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=105251'),
  ('Army: TC 3-25.26 Map Reading and Land Navigation (replaces FM 3-25.26)', 'https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=103749'),
  ('Army: TM 3-34.47 Carpentry (replaces FM 5-426)', 'https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1025240'),
  ('Army Publishing Directorate: Field Manuals', 'https://armypubs.army.mil/ProductMaps/PubForm/FM.aspx'),
  ('Army Publishing Directorate: Training Circulars', 'https://armypubs.army.mil/ProductMaps/PubForm/TC.aspx'),
  ('Army Publishing Directorate: Technical Manuals', 'https://armypubs.army.mil/ProductMaps/PubForm/TM_9.aspx'),
  ('US Navy', 'https://www.navy.mil/'),
];

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
        const Text('Blackout IQ: Griddown Resilience', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const Text('Knowledge When Everything Goes Dark.', style: TextStyle(color: AppTheme.muted)),
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
        bullet('On-device AI models, if you install them: Qwen2.5 (Apache 2.0) and all-MiniLM-L6-v2 (Apache 2.0). The AI engine is llama.cpp (MIT).'),
        bullet('Video tutorials belong to their creators and play on YouTube. The list links to videos from The Prepping Team, City Prepping, Canadian Prepper, Lead Farmer, We Da People Podcast and FEMA. Nothing is copied or downloaded.'),
        const SizedBox(height: 22),
        const Text('Official government sources', style: h),
        bullet('Blackout IQ is not a government app and is not affiliated with, endorsed by or sponsored by any government agency. It republishes US Government documents that are in the public domain, and links to the agency that issued each one. The official, current versions are always on the agency sites below. Check them for updates.'),
        for (final (what, url) in _govSources) SourceLink(label: what, url: Uri.parse(url)),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => showLicensePage(context: context, applicationName: 'Blackout IQ: Griddown Resilience', applicationVersion: kAppVersionLabel.replaceFirst('Version ', '')),
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
