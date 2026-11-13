import 'package:flutter_test/flutter_test.dart';
import 'package:ngclass/core/math/formula.dart';

void main() {
  group('formulaTex reads the simple notation', () {
    final cases = {
      '3/4 + 1/2': r'\dfrac{3}{4}+\dfrac{1}{2}',
      '(x+1)/2': r'\dfrac{x+1}{2}',
      '2x/3': r'\dfrac{2x}{3}',
      '1/2/3': r'\dfrac{\dfrac{1}{2}}{3}',
      'x^2': 'x^{2}',
      'x^(n+1)': 'x^{n+1}',
      '12^2': '{12}^{2}',
      'x^1/2': r'\dfrac{x^{1}}{2}',
      '2^(1/2)': r'2^{\frac{1}{2}}',
      'x_1 + x_2': 'x_{1}+x_{2}',
      'sqrt(9) = 3': r'\sqrt{9}=3',
      'racine(16)': r'\sqrt{16}',
      'root(3; 8)': r'\sqrt[3]{8}',
      '2,5 * 4 = 10': r'2{,}5\times 4=10',
      '2.5': '2.5',
      '12 : 4': r'12\div 4',
      'a <= b': r'a\leq b',
      'a >= b': r'a\geq b',
      'x != 0': r'x\neq 0',
      '3 < 5 > 1': '3<5>1',
      '2 pi r': r'2\pi r',
      'π': r'\pi ',
      '45°': r'45^{\circ}',
      'angle(ABC) = 90 deg': r'\widehat{ABC}=90^{\circ}',
      'vec(AB)': r'\overrightarrow{AB}',
      '3(x + 1)': r'3\left(x+1\right)',
      '-3 + 5': '-3+5',
      '50%': r'50\%',
    };
    cases.forEach((source, tex) => test(source, () => expect(formulaTex(source), tex)));
  });

  test('the window templates read while still empty: a box shows where to type', () {
    expect(formulaTex('()/()'), r'\dfrac{\square }{\square }');
    expect(formulaTex('sqrt()'), r'\sqrt{\square }');
    expect(formulaTex('x^()'), r'x^{\square }');
    expect(formulaTex('3 + '), r'3+\square ');
  });

  test('LaTeX already written passes through; empty stays empty', () {
    expect(formulaTex(r'  \frac{1}{2} '), r'\frac{1}{2}');
    expect(formulaTex('   '), '');
  });

  test('Arabic words stay text', () {
    expect(formulaTex('3 تفاحات'), r'3\text{تفاحات}');
  });

  test('a parenthesis left open cannot be read', () {
    expect(() => formulaTex('(3/4'), throwsFormatException);
    expect(() => formulaTex('3)'), throwsFormatException);
    expect(tryFormulaTex('sqrt(9'), isNull);
    expect(tryFormulaTex('sqrt(9)'), r'\sqrt{9}');
  });
}
