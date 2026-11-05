// UI for the air-gap check.
//   AirGapBanner  persistent strip at the top of every screen: SEALED / UNCONFIRMED / EXPOSED
//   AirGapGate    wraps a sensitive Stage-B screen; shows a full-screen checklist until radios are off.
//                 The user can always choose "Proceed anyway": warn, never trap someone in an emergency.

import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'airgap_monitor.dart';

class AirGapBanner extends StatelessWidget {
  const AirGapBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AirGapStatus>(
      valueListenable: AirGapMonitor.instance,
      builder: (context, s, _) {
        final (color, icon, label) = switch (s.level) {
          AirGapLevel.sealed => (AppTheme.ok, Icons.shield_outlined, 'AIR-GAPPED · all reportable radios off'),
          AirGapLevel.unconfirmed => (AppTheme.warn, Icons.help_outline, 'UNCONFIRMED · confirm Airplane Mode'),
          AirGapLevel.exposed => (AppTheme.danger, Icons.wifi_tethering_error, 'EXPOSED · ${s.activeInterfaces.join(', ')}'),
        };
        return Semantics(
          liveRegion: true,
          label: 'Air-gap status: $label',
          child: Material(
            color: AppTheme.bg,
            child: Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: color, width: 2))),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                ),
                IconButton(
                  tooltip: 'Re-check radios',
                  icon: const Icon(Icons.refresh, color: AppTheme.muted, size: 20),
                  onPressed: AirGapMonitor.instance.refresh,
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class AirGapGate extends StatefulWidget {
  const AirGapGate({super.key, required this.child, required this.featureName});
  final Widget child;
  final String featureName;

  @override
  State<AirGapGate> createState() => _AirGapGateState();
}

class _AirGapGateState extends State<AirGapGate> {
  bool _override = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AirGapStatus>(
      valueListenable: AirGapMonitor.instance,
      builder: (context, s, _) {
        if (s.isSafe || _override) return widget.child;
        return _Checklist(
          status: s,
          featureName: widget.featureName,
          onProceed: () => setState(() => _override = true),
        );
      },
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.status, required this.featureName, required this.onProceed});
  final AirGapStatus status;
  final String featureName;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    final exposed = status.level == AirGapLevel.exposed;
    final steps = Platform.isIOS
        ? const [
            'Open Control Center (swipe down from the top-right corner).',
            'Tap the airplane icon so it turns orange.',
            'Check Wi-Fi and Bluetooth are both grey. iOS turns them back on if you used them in airplane mode before.',
            'For full isolation, put the phone in an RF-shielding (Faraday) pouch while not reading.',
          ]
        : const [
            'Swipe down twice from the top of the screen to open Quick Settings.',
            'Turn on Airplane mode.',
            'Check Wi-Fi and Bluetooth tiles are off. Android remembers them if you re-enabled them in airplane mode.',
            'Turn off NFC, Nearby Share/Quick Share and hotspot if your phone shows them.',
            'For full isolation, put the phone in an RF-shielding (Faraday) pouch while not reading.',
          ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Icon(exposed ? Icons.warning_amber_rounded : Icons.help_outline, color: exposed ? AppTheme.danger : AppTheme.warn, size: 40),
            const SizedBox(height: 12),
            Text(exposed ? 'Radios are active' : 'Air gap not confirmed', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.text)),
            const SizedBox(height: 8),
            Text('Disable every network interface before opening $featureName.', style: const TextStyle(color: AppTheme.muted, fontSize: 16)),
            if (exposed) ...[
              const SizedBox(height: 20),
              const Text('Detected', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600)),
              for (final i in status.activeInterfaces)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    const Icon(Icons.circle, size: 8, color: AppTheme.danger),
                    const SizedBox(width: 10),
                    Expanded(child: Text(i, style: const TextStyle(color: AppTheme.danger))),
                  ]),
                ),
            ],
            const SizedBox(height: 24),
            const Text('Steps', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600)),
            for (var n = 0; n < steps.length; n++)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 26, child: Text('${n + 1}.', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600))),
                  Expanded(child: Text(steps[n], style: const TextStyle(color: AppTheme.text))),
                ]),
              ),
            for (final w in status.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(w, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
              ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: AirGapMonitor.instance.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Check again'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            if (Platform.isIOS && !exposed) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: AirGapMonitor.instance.confirmAirplaneMode,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text('Airplane Mode is on, Wi-Fi and Bluetooth are grey'),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: onProceed,
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: AppTheme.muted),
              child: const Text('Proceed anyway (not air-gapped)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact air-gap status for tight spaces (the Home header). Tap for the full detail and a re-check.
class AirGapChip extends StatelessWidget {
  const AirGapChip({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AirGapStatus>(
      valueListenable: AirGapMonitor.instance,
      builder: (context, s, _) {
        final (color, icon, short, long) = switch (s.level) {
          AirGapLevel.sealed => (AppTheme.ok, Icons.shield_outlined, 'AIR-GAPPED', 'All reportable radios are off.'),
          AirGapLevel.unconfirmed => (AppTheme.warn, Icons.help_outline, 'CHECK', 'Cannot confirm the radios are off. Turn on Airplane Mode and re-check.'),
          AirGapLevel.exposed => (AppTheme.danger, Icons.wifi_tethering_error, 'EXPOSED', 'Radios are on: ${s.activeInterfaces.join(', ')}. Turn on Airplane Mode to air-gap this device.'),
        };
        return Semantics(
          button: true,
          liveRegion: true,
          label: 'Air-gap status: $short. $long',
          child: Material(
            color: const Color(0xCC061410),
            shape: StadiumBorder(side: BorderSide(color: color, width: 1.5)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: AppTheme.card,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (ctx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(icon, color: color),
                        const SizedBox(width: 10),
                        Text(short, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.6)),
                      ]),
                      const SizedBox(height: 10),
                      Text(long),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: AirGapMonitor.instance.refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Re-check radios'),
                      ),
                    ]),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 5),
                  Text(short, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
