// Landing screen, laid out like the design mock: header with SOS, six artwork tiles (two per row),
// and a wide Search strip. Library, Family and Search switch to their bottom-bar tabs.

import 'package:flutter/material.dart';

import '../airgap/airgap_banner.dart';
import '../core/theme.dart';
import 'ask_screen.dart';
import 'checklist_screen.dart';
import 'plan_screen.dart';
import 'problem_solver_screen.dart';
import 'sos_screen.dart';

/// Bottom-bar positions, shared with HomeShell.
class AppTab {
  static const home = 0,
      library = 1,
      videos = 2,
      family = 3,
      search = 4,
      settings = 5;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  /// Switches the bottom bar to another tab (used by the Library, Family and Search tiles).
  final ValueChanged<int> onOpenTab;

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    // The artwork is square-cropped from the bottom so each tile's baked-in icon, title and tagline stay visible.
    final tiles = <_ArtTile>[
      _ArtTile(
        'assets/home/checklist.png',
        'Survival Kit Checklist, be prepared',
        1.0,
        () => _push(context, const ChecklistScreen()),
      ),
      _ArtTile(
        'assets/home/problem_solver.png',
        'Step By Step Problem Solver, find solutions',
        1.0,
        () => _push(
          context,
          const AirGapGate(
            featureName: 'the Problem Solver',
            child: ProblemSolverScreen(),
          ),
        ),
      ),
      _ArtTile(
        'assets/home/answer.png',
        'Answer Questions, get the facts',
        0.8,
        () => _push(
          context,
          const AirGapGate(featureName: 'AI questions', child: AskScreen()),
        ),
      ),
      _ArtTile(
        'assets/home/plan.png',
        'Generate Priority Plan, stay focused',
        0.4,
        () => _push(
          context,
          const AirGapGate(
            featureName: 'the Priority Plan',
            child: PlanScreen(),
          ),
        ),
      ),
      _ArtTile(
        'assets/home/library.png',
        'Library, learn and grow',
        0.0,
        () => onOpenTab(AppTab.library),
      ),
      _ArtTile(
        'assets/home/family.png',
        'Family, prepare together',
        1.0,
        () => onOpenTab(AppTab.family),
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: the lantern picture fills the card and is cropped from the right on narrow screens (the lantern stays
          // visible); the title and SOS button are live widgets drawn over the quiet dark part of the picture.
          // The card is a fixed-size picture with live text on top, so its text keeps its normal size however large the
          // system text is set (otherwise the tagline is cut off, like the text baked into the tile pictures).
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.0,
            child: SizedBox(
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_tileRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/home/header_bg.jpg',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerLeft,
                      filterQuality: FilterQuality.medium,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_tileRadius),
                        border: Border.all(color: _tileBorder),
                      ),
                    ),
                    Positioned(
                      left: 104,
                      right: 112,
                      top: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Blackout IQ:\nGriddown Resilience',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                    color: const Color(0xFFF6F1E7),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Knowledge When Everything Goes Dark.',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    // SOS sits in the top-right corner and the status pill in the bottom-right, well apart from each
                    // other and clear of the title.
                    Positioned(
                      right: 12,
                      top: 12,
                      child: FilledButton.icon(
                        onPressed: () => _push(context, const SosScreen()),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.sos,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                        ),
                        icon: const Icon(Icons.sos),
                        label: const Text(
                          'SOS',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 12,
                      bottom: 12,
                      child: AirGapChip(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < tiles.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(child: AspectRatio(aspectRatio: 1, child: tiles[i])),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AspectRatio(aspectRatio: 1, child: tiles[i + 1]),
                  ),
                ],
              ),
            ),
          _SearchStrip(onTap: () => onOpenTab(AppTab.search)),
        ],
      ),
    );
  }
}

const _tileRadius = 18.0;
const _tileBorder = Color(0xFF2E6B52);

class _ArtTile extends StatelessWidget {
  const _ArtTile(this.asset, this.label, this.alignY, this.onTap);
  final String asset;
  final String label;

  /// Vertical crop position: 1 = keep the bottom of the picture, lower values show more of the top.
  final double alignY;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_tileRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: Alignment(0, alignY),
              filterQuality: FilterQuality.medium,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_tileRadius),
                border: Border.all(color: _tileBorder),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wide Search strip. Drawn in code (the supplied artwork is too tall for a strip), over the same map picture.
class _SearchStrip extends StatelessWidget {
  const _SearchStrip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search, find what you need',
      excludeSemantics: true,
      // Same reason as the header: a fixed-size picture with text drawn over it.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.0,
        child: SizedBox(
          height: 128,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_tileRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/home/search_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Color(0xE6061410)],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_tileRadius),
                    border: Border.all(color: _tileBorder),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E3B),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF4AA57A),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'FIND WHAT YOU NEED',
                      style: TextStyle(
                        color: Color(0xFFBFD8CB),
                        fontSize: 11,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: onTap),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
