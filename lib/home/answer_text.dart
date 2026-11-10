// Turns the language model's light Markdown into plain styled text. The model writes **bold**, "* " bullets and
// "# " headings; showing those symbols raw looks unfinished. This handles only those three, on purpose: anything
// else the model writes passes through unchanged, so the answer's wording is never altered.

import 'package:flutter/painting.dart';

/// Builds a [TextSpan] for [answer]. Safe on a half-finished answer while it streams: an opening ** that has not been
/// closed yet is dropped (the text after it is simply shown as plain text until the closing ** arrives).
TextSpan answerSpan(String answer, TextStyle base) {
  final children = <InlineSpan>[];
  final lines = answer.split('\n');
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    var style = base;

    final heading = RegExp(r'^\s{0,3}#{1,6}\s+').firstMatch(line);
    if (heading != null) {
      line = line.substring(heading.end);
      style = base.copyWith(fontWeight: FontWeight.w800);
    }
    // "* item" and "- item" become a bullet. "**bold**" at the start of a line must not be mistaken for one.
    final bullet = RegExp(r'^(\s*)[*-]\s+(?!\*)').firstMatch(line);
    if (bullet != null) line = '${bullet.group(1)}•  ${line.substring(bullet.end)}';

    children.addAll(_inline(line, style));
    if (i < lines.length - 1) children.add(TextSpan(text: '\n', style: base));
  }
  return TextSpan(style: base, children: children);
}

List<InlineSpan> _inline(String line, TextStyle style) {
  final out = <InlineSpan>[];
  final parts = line.split('**');
  // An even number of parts means an odd number of ** markers: the last one is still open, so it is not bold yet.
  final hasOpenMarker = parts.length.isEven;
  for (var i = 0; i < parts.length; i++) {
    final text = parts[i];
    if (text.isEmpty) continue;
    final inBold = i.isOdd && !(hasOpenMarker && i == parts.length - 1);
    out.add(TextSpan(text: text, style: inBold ? style.copyWith(fontWeight: FontWeight.w800) : style));
  }
  return out;
}
