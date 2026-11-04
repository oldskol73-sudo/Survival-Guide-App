// Converts free-form user input into a safe SQLite FTS5 MATCH expression.
//
// Supported input:  water AND (boil OR bleach)   "pressure canner"   canner*   tourniquet -combat   NOT smoke
// Every term is emitted as a quoted FTS5 string, so punctuation such as "FM 21-10" or "C++" can never
// produce a syntax error. Operators are balanced and dangling ones dropped.

class FtsQuery {
  FtsQuery._();

  static final _tokenRe = RegExp(r'"([^"]*)"\*?|\(|\)|[^\s()"]+');

  /// Returns null when nothing searchable remains (e.g. input was only operators).
  static String? build(String input) {
    final out = <String>[];
    var depth = 0;
    var dropNext = false; // NOT with nothing on its left: the next term is an exclusion
    final pendingNots = <String>[]; // top-level exclusions moved to the end ("-a b" -> "b NOT a")

    bool lastIsOperand() => out.isNotEmpty && (out.last == ')' || out.last.startsWith('"'));
    bool lastIsOperator() => out.isNotEmpty && const {'AND', 'OR', 'NOT'}.contains(out.last);

    void addOperand(String term, {bool prefix = false}) {
      final cleaned = term.replaceAll('"', '""').trim();
      if (cleaned.isEmpty) return;
      final quoted = prefix ? '"$cleaned"*' : '"$cleaned"';
      if (dropNext) {
        dropNext = false;
        if (depth == 0) pendingNots.add(quoted); // inside "(...)" it cannot be placed safely: dropped
        return;
      }
      // Bare adjacency means AND in FTS5; nothing to insert.
      out.add(quoted);
    }

    void addOperator(String op) {
      if (lastIsOperator()) {
        // "a AND NOT b" -> "a NOT b" (FTS5's NOT is binary: a AND-NOT); other doubled operators: keep the first.
        if (op == 'NOT') {
          out
            ..removeLast()
            ..add('NOT');
        }
        return;
      }
      if (!lastIsOperand()) {
        // Nothing on the left (start of query or after "("). FTS5 cannot express "NOT x" there, so x is
        // never turned into a positive match: at top level it is re-attached at the end, else dropped.
        if (op == 'NOT') dropNext = true;
        return;
      }
      out.add(op);
    }

    for (final m in _tokenRe.allMatches(input)) {
      final tok = m.group(0)!;
      if (m.group(1) != null) {
        addOperand(m.group(1)!, prefix: tok.endsWith('*'));
        continue;
      }
      switch (tok) {
        case '(':
          out.add('(');
          depth++;
        case ')':
          if (depth == 0) continue;
          if (out.isNotEmpty && out.last == '(') {
            out.removeLast(); // empty group
          } else {
            if (lastIsOperator()) out.removeLast();
            out.add(')');
          }
          depth--;
        default:
          final upper = tok.toUpperCase();
          if (upper == 'AND' || upper == 'OR' || upper == 'NOT') {
            addOperator(upper);
          } else if (tok.startsWith('-') && tok.length > 1) {
            addOperator('NOT');
            addOperand(tok.substring(1).replaceAll('*', ''), prefix: tok.endsWith('*'));
          } else {
            final prefix = tok.endsWith('*') && tok.length > 1;
            addOperand(prefix ? tok.substring(0, tok.length - 1).replaceAll('*', '') : tok.replaceAll('*', ''), prefix: prefix);
          }
      }
    }

    while (lastIsOperator() || (out.isNotEmpty && out.last == '(')) {
      if (out.last == '(') depth--;
      out.removeLast();
    }
    for (; depth > 0; depth--) {
      out.add(')');
    }
    if (!out.any((t) => t.startsWith('"'))) return null;
    if (pendingNots.isEmpty) return out.join(' ');
    // NOT binds tighter than AND/OR in FTS5, so group the positive part before excluding.
    return '( ${out.join(' ')} ) ${pendingNots.map((n) => 'NOT $n').join(' ')}';
  }

  /// Fallback used if FTS5 still rejects the expression: the whole input as one phrase.
  static String asPhrase(String input) => '"${input.replaceAll('"', '""').trim()}"';

  static const _stop = {
    'a', 'an', 'the', 'and', 'or', 'but', 'if', 'then', 'so', 'of', 'to', 'in', 'on', 'at', 'by', 'for', 'with', 'from',
    'as', 'is', 'are', 'was', 'were', 'be', 'been', 'being', 'am', 'do', 'does', 'did', 'doing', 'have', 'has', 'had',
    'having', 'i', 'me', 'my', 'mine', 'we', 'us', 'our', 'you', 'your', 'he', 'she', 'it', 'its', 'they', 'them',
    'their', 'this', 'that', 'these', 'those', 'there', 'here', 'what', 'which', 'who', 'whom', 'whose', 'when',
    'where', 'why', 'how', 'can', 'could', 'should', 'would', 'will', 'shall', 'may', 'might', 'must', 'not', 'no',
    'nor', 'too', 'very', 'just', 'about', 'into', 'over', 'under', 'up', 'down', 'out', 'off', 'again', 'also',
    'than', 'any', 'some', 'such', 'only', 'own', 'same', 'both', 'each', 'few', 'more', 'most', 'other', 'get',
    'got', 'make', 'made', 'need', 'needs', 'want', 'wants', 'like', 'use', 'using', 'used', 'please', 'help', 'one',
    'two',
  };

  /// The content words of a typed sentence ("My only water source is a muddy stream" -> water, source, muddy,
  /// stream). Used for questions written in plain language, where requiring EVERY word to appear on one page
  /// (the default for typed search) finds nothing.
  static List<String> contentWords(String input) {
    final seen = <String>{};
    for (final m in RegExp(r"[A-Za-z0-9][A-Za-z0-9'-]*").allMatches(input.toLowerCase())) {
      final w = m.group(0)!.replaceAll("'", '');
      if (w.length >= 2 && !_stop.contains(w)) seen.add(w);
    }
    return seen.toList();
  }
}
