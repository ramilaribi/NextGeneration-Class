/// What the teacher types in the formula window, read into LaTeX for the screen (release 3, decision
/// 2026-10-08): 3/4 a fraction, x^2 a power, x_1 an index, sqrt(9) or racine(9) a root, root(3; 8) a cube
/// root, * a ×, : a ÷, <= ≤, >= ≥, != ≠, pi π, 45° or 45 deg a degree, vec(AB) a vector, angle(ABC) an
/// angle. "2,5" keeps its comma. Text that starts with a backslash is LaTeX already and passes through.
///
/// Throws [FormatException] when the text cannot be read (a parenthesis left open): the window says so
/// and the page shows the text as typed.
String formulaTex(String source) {
  final text = source.trim();
  if (text.isEmpty) return '';
  if (text.startsWith(r'\')) return text;
  final parser = _Parser(_tokens(text));
  final tex = parser.expression();
  if (!parser.done) throw FormatException('unexpected ${parser.peek?.text}', source);
  return tex;
}

/// [formulaTex], or null when it cannot be read.
String? tryFormulaTex(String source) {
  try {
    return formulaTex(source);
  } on FormatException {
    return null;
  }
}

enum _Kind { number, word, symbol, open, close, other }

class _Token {
  const _Token(this.kind, this.text);

  final _Kind kind;
  final String text;
}

final _letter = RegExp(r'[A-Za-zÀ-ɏ\u0600-\u06FF]');
final _digit = RegExp(r'[0-9]');

List<_Token> _tokens(String text) {
  final out = <_Token>[];
  var i = 0;
  bool at(int j, RegExp pattern) => j < text.length && pattern.hasMatch(text[j]);
  while (i < text.length) {
    final c = text[i];
    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    if (at(i, _digit)) {
      var j = i;
      while (at(j, _digit)) {
        j++;
      }
      // "2,5" and "2.5": a decimal only when a digit follows at once ("root(3; 8)" keeps its separator).
      if (j + 1 < text.length && (text[j] == ',' || text[j] == '.') && at(j + 1, _digit)) {
        j++;
        while (at(j, _digit)) {
          j++;
        }
      }
      out.add(_Token(_Kind.number, text.substring(i, j)));
      i = j;
      continue;
    }
    if (at(i, _letter)) {
      var j = i;
      while (at(j, _letter)) {
        j++;
      }
      out.add(_Token(_Kind.word, text.substring(i, j)));
      i = j;
      continue;
    }
    final two = i + 1 < text.length ? text.substring(i, i + 2) : '';
    if (two == '<=' || two == '>=' || two == '!=') {
      out.add(_Token(_Kind.symbol, two));
      i += 2;
      continue;
    }
    if (c == '(' || c == '[') {
      out.add(_Token(_Kind.open, c));
    } else if (c == ')' || c == ']') {
      out.add(_Token(_Kind.close, c));
    } else if ('+-−*×:÷/^_=<>≤≥≠;°π'.contains(c)) {
      out.add(_Token(_Kind.symbol, c));
    } else {
      out.add(_Token(_Kind.other, c));
    }
    i++;
  }
  return out;
}

/// A piece of the formula. A group in parentheses keeps them, except as a fraction's part or an exponent.
class _Node {
  const _Node(this.tex, {this.inner});

  final String tex;

  /// The group without its parentheses.
  final String? inner;

  String get bare => inner ?? tex;
}

const _relations = {'=': '=', '<': '<', '>': '>', '<=': r'\leq ', '>=': r'\geq ', '!=': r'\neq ', '≤': r'\leq ', '≥': r'\geq ', '≠': r'\neq '};
const _sums = {'+': '+', '-': '-', '−': '-'};
const _products = {'*': r'\times ', '×': r'\times ', ':': r'\div ', '÷': r'\div '};
const _empty = r'\square ';

class _Parser {
  _Parser(this._tokens);

  final List<_Token> _tokens;
  var _at = 0;

  bool get done => _at >= _tokens.length;

  _Token? get peek => done ? null : _tokens[_at];

  bool _isSymbol(Set<String> symbols) {
    final t = peek;
    return t != null && t.kind == _Kind.symbol && symbols.contains(t.text);
  }

  _Token _take() => _tokens[_at++];

  /// Relations and sums, the lowest level. [small]: inside an exponent or an index (no display fractions).
  String expression({bool small = false}) {
    final out = StringBuffer(_sum(small));
    while (_isSymbol(_relations.keys.toSet())) {
      out
        ..write(_relations[_take().text])
        ..write(_sum(small));
    }
    return out.toString();
  }

  String _sum(bool small) {
    final out = StringBuffer();
    // A leading sign: "-3 + 5".
    if (_isSymbol(_sums.keys.toSet())) out.write(_sums[_take().text]);
    out.write(_term(small));
    while (_isSymbol(_sums.keys.toSet())) {
      out
        ..write(_sums[_take().text])
        ..write(_term(small));
    }
    return out.toString();
  }

  String _term(bool small) {
    final out = StringBuffer(_fraction(small).tex);
    while (_isSymbol(_products.keys.toSet())) {
      out
        ..write(_products[_take().text])
        ..write(_fraction(small).tex);
    }
    return out.toString();
  }

  /// "3/4", "(x+1)/2", "1/2/3" (from the left).
  _Node _fraction(bool small) {
    var node = _product(small);
    while (_isSymbol({'/'})) {
      _take();
      final denominator = _product(small);
      node = _Node('${small ? r'\frac' : r'\dfrac'}{${_or(node.bare)}}{${_or(denominator.bare)}}');
    }
    return node;
  }

  /// "2x", "3(x+1)": side by side, no sign between.
  _Node _product(bool small) {
    final parts = <_Node>[];
    while (_startsAtom()) {
      parts.add(_power(small));
    }
    if (parts.isEmpty) return const _Node(_empty);
    if (parts.length == 1) return parts.single;
    return _Node(parts.map((p) => p.tex).join());
  }

  bool _startsAtom() {
    final t = peek;
    if (t == null) return false;
    return switch (t.kind) {
      _Kind.number || _Kind.word || _Kind.open || _Kind.other => true,
      _Kind.symbol => t.text == 'π',
      _Kind.close => false,
    };
  }

  /// "x^2", "x_1", "x^(n+1)", "45°", "45 deg".
  _Node _power(bool small) {
    var node = _atom(small);
    while (true) {
      if (_isSymbol({'^', '_'})) {
        final mark = _take().text;
        final exponent = _startsAtom() ? _atom(true).bare : _empty;
        node = _Node('${_brace(node.tex)}$mark{$exponent}');
      } else if (_isSymbol({'°'}) || (peek?.kind == _Kind.word && peek!.text == 'deg')) {
        _take();
        node = _Node('${node.tex}^{\\circ}');
      } else {
        return node;
      }
    }
  }

  _Node _atom(bool small) {
    final t = _take();
    switch (t.kind) {
      case _Kind.number:
        return _Node(t.text.replaceAll(',', '{,}'));
      case _Kind.symbol:
        return const _Node(r'\pi ');
      case _Kind.other:
        return _Node(_escape(t.text));
      case _Kind.open:
        final inner = expression(small: small);
        _close(t.text);
        final (left, right) = t.text == '(' ? (r'\left(', r'\right)') : (r'\left[', r'\right]');
        return _Node('$left${_or(inner)}$right', inner: inner);
      case _Kind.close:
        throw FormatException('unexpected ${t.text}');
      case _Kind.word:
        return _word(t.text, small);
    }
  }

  _Node _word(String word, bool small) {
    String argument() {
      if (peek?.kind != _Kind.open) return _empty;
      final open = _take().text;
      final inner = expression(small: small);
      _close(open);
      return _or(inner);
    }

    switch (word.toLowerCase()) {
      case 'pi':
        return const _Node(r'\pi ');
      case 'sqrt' || 'racine':
        return _Node('\\sqrt{${argument()}}');
      case 'root':
        // root(3; 8): the cube root of 8.
        if (peek?.kind != _Kind.open) return const _Node('\\sqrt{$_empty}');
        final open = _take().text;
        final index = expression(small: true);
        var radicand = _empty;
        if (_isSymbol({';'})) {
          _take();
          radicand = _or(expression(small: small));
        }
        _close(open);
        return _Node('\\sqrt[${_or(index)}]{$radicand}');
      case 'vec':
        return _Node('\\overrightarrow{${argument()}}');
      case 'angle':
        return _Node('\\widehat{${argument()}}');
    }
    // Arabic stays as written; letters are the formula's own (x, AB).
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(word)) return _Node('\\text{$word}');
    return _Node(word);
  }

  void _close(String open) {
    final t = peek;
    if (t == null || t.kind != _Kind.close) throw FormatException('$open left open');
    _take();
  }

  static String _or(String tex) => tex.trim().isEmpty ? _empty : tex;

  /// "x^2" stays "x^{2}"; "2x" raised needs braces: "{2x}^{2}".
  static String _brace(String tex) => tex.length == 1 || tex.startsWith(r'\left') || tex.endsWith('}') ? tex : '{$tex}';

  static String _escape(String c) => switch (c) {
    '%' || '&' || '#' || r'$' || '{' || '}' => '\\$c',
    r'\' => r'\backslash ',
    '~' || '^' => '\\text{$c}',
    _ => c,
  };
}
