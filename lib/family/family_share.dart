// Share and import the Family tab as an encrypted QR code (or the same code as text).
//
// Share: the user picks a passphrase, the family details are encrypted with it (see family_code.dart) and shown
// as a QR code. Import: scan the QR code (or paste the text), then type the passphrase the sender told you.
// Nothing leaves the phone except through the message the user sends themselves.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme.dart';
import 'family_code.dart';
import 'family_store.dart';

// ------------------------------------------------------------------------------------------------ share

Future<void> shareFamilyCode(BuildContext context, FamilyStore store) async {
  final messenger = ScaffoldMessenger.of(context);
  if (store.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Add a member, contact or place first.')),
    );
    return;
  }
  final passphrase = await _askNewPassphrase(context);
  if (passphrase == null || !context.mounted) return;

  final code = await _withBusyDialog(
    context,
    'Encrypting…',
    () => FamilyCode.seal(store.exportJson(), passphrase),
  );
  if (code == null || !context.mounted) return;
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => _ShareCodeScreen(code: code)));
}

Future<String?> _askNewPassphrase(BuildContext context) {
  final first = TextEditingController();
  final second = TextEditingController();
  var hidden = true;
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: AlertDialog(
          // Compact, so both fields and the buttons stay visible above the keyboard.
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
          contentPadding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
          title: Text(
            'Set a passphrase',
            style: Theme.of(
              ctx,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'It locks the QR code. Tell it to your family in person or by phone, not in the same message as the code.',
                  style: TextStyle(
                    color: AppTheme.muted,
                    height: 1.3,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: first,
                  obscureText: hidden,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Passphrase',
                    helperText:
                        'At least 8 characters. Several words is easy to remember.',
                    suffixIcon: IconButton(
                      tooltip: hidden ? 'Show' : 'Hide',
                      icon: Icon(
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => hidden = !hidden),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: second,
                  obscureText: hidden,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Type it again',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final a = first.text.trim();
                if (a.length < FamilyCode.minPassphraseLength) {
                  setState(
                    () => error =
                        'Use at least ${FamilyCode.minPassphraseLength} characters.',
                  );
                } else if (a != second.text.trim()) {
                  setState(() => error = 'The two passphrases do not match.');
                } else {
                  Navigator.pop(ctx, a);
                }
              },
              child: const Text('Create QR'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShareCodeScreen extends StatelessWidget {
  const _ShareCodeScreen({required this.code});
  final String code;

  // A QR code holds at most ~2,900 characters at the lowest error correction. Beyond that, only the text can be shared.
  bool get _fitsInQr =>
      QrValidator.validate(
        data: code,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      ).status ==
      QrValidationStatus.valid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family code')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: const [
              Icon(Icons.lock_rounded, color: AppTheme.accent, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Encrypted with AES-256',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Anyone can scan this, but only someone with your passphrase can read it.',
            style: TextStyle(color: AppTheme.muted, height: 1.3, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (_fitsInQr)
            Center(
              child: Semantics(
                label: 'Encrypted family code as a QR code',
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Fills the width on a small phone, and never grows past 260 so the Copy button stays in view.
                    final side = (box.maxWidth - 24).clamp(180.0, 260.0);
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        data: code,
                        version: QrVersions.auto,
                        errorCorrectionLevel: QrErrorCorrectLevel.L,
                        size: side,
                        backgroundColor: Colors.white,
                        gapless: true,
                      ),
                    );
                  },
                ),
              ),
            )
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'There is too much information for one QR code. Use Copy code below and send it as a message.',
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy code as text'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: code));
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Encrypted code copied. It cannot be read without your passphrase.',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'How your family gets it',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 2),
          const _Step(
            '1',
            'On their phone: Family, Import, Scan QR code. Point the camera here.',
          ),
          const _Step(
            '2',
            'Tell them your passphrase in person or by phone, not with the code.',
          ),
          const _Step('3', 'They type it and your family details are added.'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.text);
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Text(
            n,
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );
}

// ------------------------------------------------------------------------------------------------ import

enum _Source { scan, paste }

Future<void> importFamilyCode(BuildContext context, FamilyStore store) async {
  final source = await showModalBottomSheet<_Source>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Import a family code',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner_rounded),
            title: const Text('Scan QR code'),
            subtitle: const Text('Point the camera at the other phone'),
            onTap: () => Navigator.pop(ctx, _Source.scan),
          ),
          ListTile(
            leading: const Icon(Icons.paste_rounded),
            title: const Text('Paste code'),
            subtitle: const Text('For a code that was sent as a message'),
            onTap: () => Navigator.pop(ctx, _Source.paste),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  String? code;
  if (source == _Source.scan) {
    code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _ScanScreen()));
  } else {
    code = await _askPastedCode(context);
  }
  if (code == null || !context.mounted) return;
  await _applyCode(context, store, code);
}

Future<String?> _askPastedCode(BuildContext context) async {
  final c = TextEditingController();
  final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
  if (FamilyCode.isEncrypted(clip) || FamilyCode.isLegacy(clip))
    c.text = clip.trim();
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Paste family code'),
      content: TextField(
        controller: c,
        minLines: 2,
        maxLines: 5,
        autocorrect: false,
        decoration: const InputDecoration(
          hintText: 'Paste the code you received',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

/// Reads whatever the user scanned or pasted: ask for the passphrase when it is encrypted, then merge it in.
Future<void> _applyCode(
  BuildContext context,
  FamilyStore store,
  String raw,
) async {
  final messenger = ScaffoldMessenger.of(context);
  void report(int? added) => messenger.showSnackBar(
    SnackBar(
      content: Text(
        added == null
            ? 'That is not a valid family code.'
            : added == 0
            ? 'Nothing new to add. Everything in that code is already here.'
            : 'Added $added new ${added == 1 ? 'entry' : 'entries'}.',
      ),
    ),
  );

  if (FamilyCode.isLegacy(raw)) {
    report(await store.importCode(raw));
    return;
  }
  if (!FamilyCode.isEncrypted(raw)) {
    report(null);
    return;
  }

  String? problem;
  while (true) {
    if (!context.mounted) return;
    final passphrase = await _askPassphrase(context, problem);
    if (passphrase == null || !context.mounted) return;
    try {
      final json = await _withBusyDialog(
        context,
        'Unlocking…',
        () => FamilyCode.open(raw, passphrase),
      );
      if (json == null || !context.mounted) return;
      report(await store.importJson(json));
      return;
    } on FamilyCodeException catch (e) {
      if (e.error == FamilyCodeError.notACode) {
        report(null);
        return;
      }
      problem =
          'That passphrase did not unlock the code. Check it and try again.';
      if (!context.mounted) return;
    }
  }
}

Future<String?> _askPassphrase(BuildContext context, String? problem) {
  final c = TextEditingController();
  var hidden = true;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
          contentPadding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
          title: Text(
            'Enter the passphrase',
            style: Theme.of(
              ctx,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ask the person who shared this code for the passphrase they chose.',
                style: TextStyle(
                  color: AppTheme.muted,
                  height: 1.3,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: c,
                obscureText: hidden,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Passphrase',
                  errorText: problem,
                  errorMaxLines: 3,
                  suffixIcon: IconButton(
                    tooltip: hidden ? 'Show' : 'Hide',
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => hidden = !hidden),
                  ),
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScanScreen extends StatefulWidget {
  const _ScanScreen();
  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;
  bool _notOurs = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v == null) continue;
      if (FamilyCode.isEncrypted(v) || FamilyCode.isLegacy(v)) {
        _done = true;
        Navigator.of(context).pop(v);
        return;
      }
    }
    // A QR code, but not one of ours (a website, a Wi-Fi code, ...). Say so instead of silently ignoring it.
    if (!_notOurs) setState(() => _notOurs = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan family code')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.no_photography_outlined,
                      size: 44,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      error.errorCode == MobileScannerErrorCode.permissionDenied
                          ? 'Camera access is off. Turn it on for Blackout IQ in your phone settings, or go back and choose Paste code.'
                          : 'The camera could not start. Go back and choose Paste code instead.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.65),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: SafeArea(
                top: false,
                child: Text(
                  _notOurs
                      ? 'That QR code is not a Blackout IQ family code.'
                      : 'Point the camera at the QR code on the other phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _notOurs ? AppTheme.warn : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ helpers

/// Shows a small "working" dialog while [job] runs (the key derivation takes a moment), then closes it.
Future<T?> _withBusyDialog<T>(
  BuildContext context,
  String message,
  Future<T> Function() job,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 18),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
  try {
    return await job();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
