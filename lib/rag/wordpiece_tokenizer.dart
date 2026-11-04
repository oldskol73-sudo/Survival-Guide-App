// Minimal BERT "uncased" WordPiece tokenizer for all-MiniLM-L6-v2 (vocab.txt, 30,522 entries).
// Matches HF BertTokenizer for ASCII/Latin technical text: lower-case, split on whitespace and
// punctuation, CJK characters isolated, greedy longest-match WordPiece with "##" continuation.
// Accent stripping covers Latin-1 and Latin Extended-A, which is what English field manuals contain.

import 'dart:io';
import 'dart:typed_data';

class Encoded {
  Encoded(this.inputIds, this.attentionMask, this.tokenTypeIds);
  final Int64List inputIds;
  final Int64List attentionMask;
  final Int64List tokenTypeIds;
  int get length => inputIds.length;
}

class WordPieceTokenizer {
  WordPieceTokenizer._(this._vocab, this._cls, this._sep, this._unk);

  final Map<String, int> _vocab;
  final int _cls, _sep, _unk;
  static const maxInputCharsPerWord = 100;

  static Future<WordPieceTokenizer> fromVocabFile(String path) async {
    final lines = await File(path).readAsLines();
    final vocab = <String, int>{for (var i = 0; i < lines.length; i++) lines[i]: i};
    int id(String t) => vocab[t] ?? (throw StateError('vocab missing $t'));
    return WordPieceTokenizer._(vocab, id('[CLS]'), id('[SEP]'), id('[UNK]'));
  }

  Encoded encode(String text, {int maxLen = 256}) {
    final ids = <int>[_cls];
    for (final word in _basicTokenize(text)) {
      final pieces = _wordPiece(word);
      if (ids.length + pieces.length >= maxLen) break; // keep room for [SEP]
      ids.addAll(pieces);
    }
    ids.add(_sep);
    final n = ids.length;
    return Encoded(Int64List.fromList(ids), Int64List(n)..fillRange(0, n, 1), Int64List(n));
  }

  List<int> _wordPiece(String word) {
    if (word.length > maxInputCharsPerWord) return [_unk];
    final out = <int>[];
    var start = 0;
    while (start < word.length) {
      var end = word.length;
      int? found;
      while (start < end) {
        final sub = start == 0 ? word.substring(start, end) : '##${word.substring(start, end)}';
        final id = _vocab[sub];
        if (id != null) {
          found = id;
          break;
        }
        end--;
      }
      if (found == null) return [_unk];
      out.add(found);
      start = end;
    }
    return out;
  }

  Iterable<String> _basicTokenize(String text) sync* {
    final buf = StringBuffer();
    for (final rune in _stripAccents(text.toLowerCase()).runes) {
      if (rune == 0 || rune == 0xFFFD || _isControl(rune)) continue;
      if (_isWhitespace(rune)) {
        if (buf.isNotEmpty) {
          yield buf.toString();
          buf.clear();
        }
      } else if (_isPunct(rune) || _isCjk(rune)) {
        if (buf.isNotEmpty) {
          yield buf.toString();
          buf.clear();
        }
        yield String.fromCharCode(rune);
      } else {
        buf.writeCharCode(rune);
      }
    }
    if (buf.isNotEmpty) yield buf.toString();
  }

  static bool _isWhitespace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0 || (c >= 0x2000 && c <= 0x200A);
  static bool _isControl(int c) => (c < 0x20 && c != 0x09 && c != 0x0A && c != 0x0D) || (c >= 0x7F && c < 0xA0);
  static bool _isPunct(int c) =>
      (c >= 33 && c <= 47) || (c >= 58 && c <= 64) || (c >= 91 && c <= 96) || (c >= 123 && c <= 126) ||
      (c >= 0x2010 && c <= 0x2027) || (c >= 0x2030 && c <= 0x205E) || c == 0xB0 || c == 0xB7 || c == 0xD7;
  static bool _isCjk(int c) =>
      (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF) || (c >= 0xF900 && c <= 0xFAFF) || (c >= 0x20000 && c <= 0x2FA1F);

  static const _accentFrom = 'àáâãäåāăąçćĉċčďđèéêëēĕėęěĝğġģĥħìíîïĩīĭįıĵķĺļľŀłñńņňòóôõöøōŏőŕŗřśŝşšţťŧùúûüũūŭůűųŵýÿŷźżž';
  static const _accentTo = 'aaaaaaaaacccccddeeeeeeeeegggghhiiiiiiiiijklllllnnnnooooooooorrrsssstttuuuuuuuuuuwyyyzzz';

  static String _stripAccents(String s) {
    final sb = StringBuffer();
    for (final ch in s.split('')) {
      final i = _accentFrom.indexOf(ch);
      sb.write(i >= 0 ? _accentTo[i] : ch);
    }
    return sb.toString();
  }
}
