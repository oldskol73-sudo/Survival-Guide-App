// Emergency SOS: a 911 reminder, a screen-flash SOS signal, and the built-in emergency protocols.
// Everything here works with no library, no model and no network.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import 'sos_protocols.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergencies')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.10), border: Border.all(color: AppTheme.danger), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.phone_in_talk, color: AppTheme.danger),
              SizedBox(width: 12),
              Expanded(child: Text('If you have any signal, call your local emergency number (911 in the US) first.', style: TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Signal SOS with the screen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Flashes the screen in the SOS pattern (three short, three long, three short). Hold it up toward rescuers or aircraft. Stops by itself after one minute.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _FlashSosScreen())),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.sos, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)),
                  child: const Text('FLASH SOS'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Flashing light can trigger seizures in people with photosensitive epilepsy. It is a visible signal only: it does not call anyone or send your location. Use only in a real emergency.',
                  style: TextStyle(fontSize: 12, color: AppTheme.warn),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text('${protocols.length} EMERGENCY PROTOCOLS · WORK OFFLINE', style: const TextStyle(fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w700, color: AppTheme.muted)),
          const SizedBox(height: 4),
          for (final p in protocols)
            Card(
              child: ListTile(
                leading: const Icon(Icons.emergency_outlined, color: AppTheme.danger),
                title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(p.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProtocolScreen(protocol: p))),
              ),
            ),
        ],
      ),
    );
  }
}

class ProtocolScreen extends StatelessWidget {
  const ProtocolScreen({super.key, required this.protocol});
  final Protocol protocol;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(protocol.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(protocol.subtitle, style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 12),
          for (var i = 0; i < protocol.steps.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(radius: 14, backgroundColor: AppTheme.accent, foregroundColor: AppTheme.bg, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(protocol.steps[i], style: const TextStyle(fontSize: 17, height: 1.45))),
                ]),
              ),
            ),
          if (protocol.warning != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(protocol.warning!, style: const TextStyle(color: AppTheme.warn))),
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'General first-aid summary, not a substitute for training or professional care. Call your local emergency number whenever you can.',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen SOS flasher. Morse timing: dot = 1 unit, dash = 3, gap inside a letter = 1, between letters = 3.
class _FlashSosScreen extends StatefulWidget {
  const _FlashSosScreen();
  @override
  State<_FlashSosScreen> createState() => _FlashSosScreenState();
}

class _FlashSosScreenState extends State<_FlashSosScreen> {
  static const _unit = Duration(milliseconds: 250);
  static const _pattern = <(bool, int)>[
    // S
    (true, 1), (false, 1), (true, 1), (false, 1), (true, 1), (false, 3),
    // O
    (true, 3), (false, 1), (true, 3), (false, 1), (true, 3), (false, 3),
    // S
    (true, 1), (false, 1), (true, 1), (false, 1), (true, 1), (false, 7),
  ];

  bool _on = false;
  bool _stopped = false;
  Timer? _timer;
  Timer? _limit;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _step();
    _limit = Timer(const Duration(minutes: 1), _stop);
  }

  void _step() {
    if (_stopped) return;
    final (on, units) = _pattern[_i];
    setState(() => _on = on);
    _i = (_i + 1) % _pattern.length;
    _timer = Timer(_unit * units, _step);
  }

  void _stop() {
    if (_stopped) return;
    _stopped = true;
    _timer?.cancel();
    _limit?.cancel();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _stopped = true;
    _timer?.cancel();
    _limit?.cancel();
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _on ? Colors.white : Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Center(
            child: Semantics(
              label: 'SOS signal flashing',
              child: Text('SOS', style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: _on ? Colors.black : Colors.white24)),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: FilledButton(
              onPressed: _stop,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.sos, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(60)),
              child: const Text('STOP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
