// Splits page text into overlapping word windows sized for MiniLM (256 wordpiece limit).
// 160 words is about 210-240 wordpieces for technical English; 30 words of overlap keeps a procedure
// step from being cut in half across two chunks. Chunks never span pages, so citations stay exact.

class TextChunk {
  TextChunk(this.page, this.ord, this.text);
  final int page;
  final int ord;
  final String text;
}

List<TextChunk> chunkPage(int page, String text, {int words = 160, int overlap = 30}) {
  final w = text.split(' ').where((s) => s.isNotEmpty).toList();
  if (w.length < 12) return const []; // headers, blank or image-only pages
  final out = <TextChunk>[];
  final step = words - overlap;
  for (var start = 0, ord = 0; start < w.length; start += step, ord++) {
    final end = (start + words < w.length) ? start + words : w.length;
    out.add(TextChunk(page, ord, w.sublist(start, end).join(' ')));
    if (end == w.length) break;
  }
  return out;
}
