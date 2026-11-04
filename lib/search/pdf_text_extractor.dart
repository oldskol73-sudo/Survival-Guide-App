// Page-by-page text extraction with PDFium (pdfrx). Pages are yielded one at a time so a 900-page
// manual never sits in memory as one string, and the event loop gets a turn between pages.

import 'package:pdfrx/pdfrx.dart';

class PageText {
  PageText(this.page, this.text);
  final int page; // 1-based, as printed in citations
  final String text;
}

class PdfExtractionResult {
  PdfExtractionResult(this.pageCount);
  final int pageCount;
  int pagesWithText = 0;
  bool get needsOcr => pageCount > 0 && pagesWithText / pageCount < 0.2;
}

class PdfTextExtractor {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await pdfrxFlutterInitialize(); // required when using the engine API outside a widget
    _initialized = true;
  }

  /// Streams normalised page text. Throws on unreadable or password-protected files.
  static Stream<PageText> pages(String path, PdfExtractionResult Function(int pageCount) onOpen) async* {
    await ensureInitialized();
    final doc = await PdfDocument.openFile(path);
    try {
      final result = onOpen(doc.pages.length);
      for (final page in doc.pages) {
        final raw = (await page.loadText())?.fullText ?? '';
        final text = normalize(raw);
        if (text.length > 40) result.pagesWithText++;
        yield PageText(page.pageNumber, text);
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      await doc.dispose();
    }
  }

  /// Joins hyphenated line breaks, collapses whitespace, removes control characters.
  static String normalize(String s) => s
      .replaceAllMapped(RegExp(r'(\w)-\r?\n(\w)'), (m) => '${m[1]}${m[2]}')
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), ' ')
      .replaceAll(RegExp(r'[ \t\r\n ]+'), ' ')
      .trim();
}
