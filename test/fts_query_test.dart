// flutter test test/fts_query_test.dart
// Expected outputs were validated against SQLite FTS5 (porter unicode61) during development.

import 'package:flutter_test/flutter_test.dart';
import 'package:survival_node_mobile/search/fts_query.dart';

void main() {
  final cases = <String, String?>{
    'water AND (boil OR bleach)': '"water" AND ( "boil" OR "bleach" )',
    '"pressure canner': '"pressure" "canner"', // unbalanced quote
    '"pressure canner"*': '"pressure canner"*',
    'tourniquet -combat': '"tourniquet" NOT "combat"',
    'tourniquet AND NOT combat': '"tourniquet" NOT "combat"',
    '-combat tourniquet': '( "tourniquet" ) NOT "combat"', // leading exclusion moved to the end
    'NOT smoke': null, // nothing positive to search for
    'canner*': '"canner"*',
    '((water': '( ( "water" ) )',
    'water)': '"water"',
    'water ( )': '"water"',
    'AND OR': null,
    'FM 21-10': '"FM" "21-10"',
    'C++': '"C++"',
  };

  cases.forEach((input, expected) {
    test('FtsQuery.build(${input.isEmpty ? "<empty>" : input})', () {
      expect(FtsQuery.build(input), expected);
    });
  });

  test('asPhrase escapes quotes', () {
    expect(FtsQuery.asPhrase('say "hi"'), '"say ""hi"""');
  });
}
