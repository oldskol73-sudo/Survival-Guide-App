// "How to use Blackout IQ": a swipeable tour with one picture per area of the app. Shown once on first launch and
// any time from Settings.

import 'package:flutter/material.dart';

import '../core/settings.dart';
import '../core/theme.dart';

class _TourPage {
  const _TourPage(this.image, this.title, this.body, {this.wide = false});
  final String image;
  final String title;
  final String body;
  final bool wide; // composite artwork with a longer caption
}

const _pages = <_TourPage>[
  _TourPage('assets/tour/01_welcome.jpg', 'Welcome to Blackout IQ',
      'A survival library that lives on this device. The manuals, checklists and maps work with no signal at all, so they are there when the network is not. Swipe to see how everything fits together.'),
  _TourPage('assets/tour/02_tiles.jpg', 'Six tiles, six ways to get help',
      'Survival Kit Checklist: pack and check your kit.\nStep By Step Problem Solver: describe a problem and get the best steps from the manuals.\nAnswer Questions: ask in plain words.\nGenerate Priority Plan: say what is happening and what you have, and get a ranked plan.\nLibrary and Family sit below them.\n\nWith the on-device AI model installed, answers are written out as steps. Without it, you get the exact manual passages that answer the question.',
      wide: true),
  _TourPage('assets/tour/03_home.jpg', 'Home: start here',
      'The big tiles are the jobs you will need most. The red SOS button, top right, opens emergency steps and signals. The small pill under it shows whether this device is air-gapped (radios off) or exposed. Tap it for detail.'),
  _TourPage('assets/tour/04_library.jpg', 'Library: your manuals and maps',
      'Hundreds of manuals on water, food, medical care, power, shelter, tools and more. The Field Guide groups them by topic, and Gear covers kit. Offline Maps downloads a map of your area while you have a signal, in miles around you, then works with none.'),
  _TourPage('assets/tour/05_videos.jpg', 'Videos: learn by watching',
      'About two thousand how-to video links, filed by subject and matched to the manuals that cover the same topic. You can browse offline. Watching needs internet and is switched off while the device is sealed.'),
  _TourPage('assets/tour/06_family.jpg', 'Family: prepare together',
      'Your family plan and emergency numbers in one place, plus a locked, encrypted Documents vault for IDs and papers. It opens with your fingerprint or screen lock.'),
  _TourPage('assets/tour/06b_vault.jpg', 'Documents Vault: your papers, locked',
      'One of the most important parts of the app. Photograph your passport, IDs, birth and marriage certificates, insurance, property, financial and medical records, and keep them encrypted on this device. Open it from the Family tab; it asks for your fingerprint or screen lock and locks again the moment you leave the app. Fill it in now, before you need it, because in an emergency your papers are the first thing you will be asked for.',
      wide: true),
  _TourPage('assets/tour/07_search.jpg', 'Search: find the exact page',
      'Type a word or phrase and jump straight to the page in any manual that mentions it. Use quotation marks for an exact phrase.'),
  _TourPage('assets/tour/08_settings.jpg', 'Settings: make it yours',
      'Choose where the library is stored (internal or SD card), turn on low-power mode, control background AI indexing, and seal the node for air-gapped use. You can replay this tour from the top of Settings at any time.'),
];

class TourScreen extends StatefulWidget {
  const TourScreen({super.key});
  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  final _pc = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!AppSettings.instance.tourSeen) await AppSettings.instance.update((s) => s.tourSeen = true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _finish, child: Text(last ? 'Close' : 'Skip')),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (context, i) {
                final p = _pages[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(p.image, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(p.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                    const SizedBox(height: 6),
                    Expanded(
                      flex: p.wide ? 4 : 3,
                      child: SingleChildScrollView(child: Text(p.body, style: const TextStyle(fontSize: 15, height: 1.4, color: AppTheme.muted))),
                    ),
                  ]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Row(children: [
              SizedBox(
                width: 84,
                child: _i == 0
                    ? null
                    : TextButton(onPressed: () => _pc.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut), child: const Text('Back')),
              ),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var d = 0; d < _pages.length; d++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: d == _i ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(color: d == _i ? AppTheme.accent : AppTheme.outline, borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
              ),
              SizedBox(
                width: 84,
                child: FilledButton(
                  onPressed: last ? _finish : () => _pc.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: AppTheme.bg),
                  child: Text(last ? 'Done' : 'Next'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
