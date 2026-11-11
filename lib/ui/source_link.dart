// A tappable link to the official publisher of a document, opened in the phone's browser.
// Play's Misleading Claims policy needs government information to point at its original source.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

Future<void> openSource(BuildContext context, Uri url) async {
  final ok = await launchUrl(url, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${url.host}. Address: $url')));
  }
}

class SourceLink extends StatelessWidget {
  const SourceLink({super.key, required this.url, this.label});
  final Uri url;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openSource(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.open_in_new, size: 14, color: AppTheme.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label ?? 'Official source: ${url.host}${url.path == '/' ? '' : url.path}',
                style: const TextStyle(color: AppTheme.accent, fontSize: 12, decoration: TextDecoration.underline)),
          ),
        ]),
      ),
    );
  }
}
