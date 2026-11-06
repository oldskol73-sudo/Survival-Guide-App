// Publisher masthead: the picture strip at the very top of every screen. The air-gap status lives in the
// status pill on the Home header (see AirGapChip), not here.

import 'package:flutter/material.dart';

import '../core/theme.dart';

class Masthead extends StatelessWidget {
  const Masthead({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Blackout IQ by Twelve Scents Publishing',
      image: true,
      child: Container(
        height: 92,
        color: AppTheme.bg,
        child: Image.asset('assets/home/masthead.jpg', fit: BoxFit.cover, alignment: Alignment.center, width: double.infinity, filterQuality: FilterQuality.medium),
      ),
    );
  }
}
