import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survival_node_mobile/home/answer_text.dart';

String plain(String s) => answerSpan(s, const TextStyle()).toPlainText();

void main() {
  test('bold markers are removed and the text kept', () {
    expect(plain('1. **Boiling**: Bring water to a boil [S1].'), '1. Boiling: Bring water to a boil [S1].');
  });

  test('numbers, citations and maths are untouched', () {
    expect(plain('Use 8.25% [S2]. 2 * 3 = 6 and 5*4=20'), 'Use 8.25% [S2]. 2 * 3 = 6 and 5*4=20');
  });

  test('an unclosed ** while streaming shows no asterisks', () {
    expect(plain('Step one: **Boil'), 'Step one: Boil');
  });

  test('bullets become dots', () {
    expect(plain('* item\n- other'), '•  item\n•  other');
  });

  test('headings lose the hashes', () {
    expect(plain('## Steps\nGo'), 'Steps\nGo');
  });

  test('bold at line start is not a bullet', () {
    expect(plain('**Warning:** boil first'), 'Warning: boil first');
  });

  test('empty string is fine', () {
    expect(plain(''), '');
  });
}
