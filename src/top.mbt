///|
#derive(Debug)
pub(all) struct Input {
  chars : StringView
  row : Int32
  col : Int32
}

///|
pub fn Input::new(chars : StringView) -> Input {
  Input::{ chars, row: 0, col: 0, }
}

///|
#derive(Debug)
pub(all) suberror ParseError {
  Many(Array[ParseError])
  Expect(row~ : Int32, col~ : Int32, String)
}

///|
pub(all) struct Parser[A]((Input) -> (A, Input) raise ParseError)

///|
pub fn[A] Parser::run(self : Parser[A], input : Input) -> A raise ParseError {
  (self.0)(input).0
}

///|
pub fn[A, B] Parser::bind(self : Parser[A], f : (A) -> Parser[B]) -> Parser[B] {
  Parser(input => {
    let (v, rest) = (self.0)(input)
    (f(v).0)(rest)
  })
}

///|
pub fn[A] Parser::pure(x : A) -> Parser[A] {
  Parser(input => (x, input))
}

///|
pub impl[A] BitOr for Parser[A] with fn lor(self, y) {
  Parser(input => {
    (self.0)(input) catch {
      e => (y.0)(input) catch { e_ => raise Many([e, e_]) }
    }
  })
}

///|
pub fn Parser::satisfy(f : (Char) -> Bool) -> Parser[Char] {
  Parser(input => {
    let { chars, row, col, } = input
    match chars {
      [x, .. chars] if f(x) =>
        if x == '\n' {
          (x, Input::{ chars, row: row + 1, col: 0, })
        } else {
          (x, Input::{ ..input, chars, col: col + 1, })
        }
      _ => raise Expect(row~, col~, "")
    }
  })
}

///|
pub fn[A] Parser::eof(x : A) -> Parser[A] {
  Parser(input => {
    let { chars, row, col, } = input
    match chars {
      [] => (x, input)
      _ => raise Expect(row~, col~, "eof")
    }
  })
}

///|
pub fn Parser::any(input : Input) -> (Char, Input) raise ParseError {
  (Parser::satisfy(_ => true).0)(input)
}

///|
pub fn[A] Parser::label(x : Parser[A], s : String) -> Parser[A] {
  Parser(input => {
    (x.0)(input) catch {
      Expect(row~, col~, _) => raise Expect(row~, col~, s)
      Many([Expect(row~, col~, _), ..]) => raise Expect(row~, col~, s)
      Many(_) => panic()
    }
  })
}

///|
pub fn Parser::char(ch : Char) -> Parser[Char] {
  Parser::satisfy(c => c == ch).label(ch.to_string())
}

///|
pub fn Parser::string(str : String) -> Parser[String] {
  Parser(input => {
    guard !str.contains_char('\n') else { panic() }
    let { chars, row, col, } = input
    let len = str.length()
    guard chars.length() >= len && chars[:len] == str else {
      raise Expect(row~, col~, str)
    }
    (str, Input::{ ..input, chars: chars[len:], col: len, })
  })
}

///|
pub fn[A, B] Parser::discard_left(self : Parser[A], y : Parser[B]) -> Parser[B] {
  self.bind(_ => y)
}

///|
pub fn[A, B] Parser::discard_right(
  self : Parser[A],
  y : Parser[B],
) -> Parser[A] {
  self.bind(r => y.bind(_ => Parser::pure(r)))
}

///|
pub fn[A, B, C] Parser::between(
  self : Parser[A],
  open~ : Parser[B],
  close~ : Parser[C],
) -> Parser[A] {
  open.discard_left(self).discard_right(close)
}

///|
pub fn Parser::one_of(xs : String) -> Parser[Char] {
  Parser::satisfy(ch => xs.contains_char(ch)).label(
    "one of \{Repr(xs.to_array())}}",
  )
}

///|
pub fn Parser::none_of(xs : String) -> Parser[Char] {
  Parser::satisfy(ch => !xs.contains_char(ch)).label(
    "none of \{Repr(xs.to_array())}}",
  )
}

///|
#as_free_fn
pub fn[A] Parser::foldl1(x : Parser[A], f : Parser[(A, A) -> A]) -> Parser[A] {
  fn go(a) {
    let acc = f.bind(f => x.bind(b => go(f(a, b))))
    acc | Parser::pure(a)
  }

  x.bind(go)
}

///|
pub fn[A, B] Parser::map(self : Parser[A], f : (A) -> B) -> Parser[B] {
  self.bind(x => Parser::pure(f(x)))
}

///|
pub fn[A] Parser::parens(self : Parser[A]) -> Parser[A] {
  self.between(open=Parser::char('('), close=Parser::char(')'))
}

///|
pub fn Parser::digit(input : Input) -> (Char, Input) raise ParseError {
  (Parser::satisfy(Char::is_ascii_digit).0)(input)
}

///|
// Keep the original public Show implementation alongside Debug.
pub impl Show for Input with fn output(self, logger) {
  logger.write_string("{chars: ")
  logger.write(Repr(self.chars.to_owned()))
  logger.write_string(", row: \{self.row}, col: \{self.col}}")
}

///|
pub impl Show for ParseError with fn output(self, logger) {
  match self {
    Expect(row~, col~, expected) => {
      logger.write_string("Expect(row=\{row}, col=\{col}, ")
      logger.write(Repr(expected))
      logger.write_string(")")
    }
    Many(errors) => {
      logger.write_string("Many([")
      for i, error in errors {
        if i > 0 {
          logger.write_string(", ")
        }
        logger.write(error)
      }
      logger.write_string("])")
    }
  }
}
