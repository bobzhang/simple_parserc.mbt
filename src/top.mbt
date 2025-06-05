///|
pub(all) struct Input {
  chars : @string.View
  row : Int
  col : Int
} derive(Show)

///|
pub fn Input::new(chars : @string.View) -> Input {
  Input::{ chars, row: 0, col: 0 }
}

///|
pub(all) type! ParseError {
  Many(Array[ParseError])
  Expect(row~ : Int, col~ : Int, String)
} derive(Show)

///|
pub(all) type Parser[A] (Input) -> (A, Input)!ParseError

///|
pub fn[A] Parser::run(self : Parser[A], input : Input) -> A!ParseError {
  self(input).0
}

///|
pub fn[A, B] Parser::bind(self : Parser[A], f : (A) -> Parser[B]) -> Parser[B] {
  fn(input) {
    let (v, rest) = self(input)
    f(v)(rest)
  }
}

///|
pub fn[A] Parser::pure(x : A) -> Parser[A] {
  fn(input) { (x, input) }
}

///|
pub impl[A] BitOr for Parser[A] with lor(self, y) {
  fn(input) {
    try self(input) catch {
      e =>
        try y(input) catch {
          e_ => raise Many([e, e_])
        }
    }
  }
}

///|
pub fn Parser::satisfy(f : (Char) -> Bool) -> Parser[Char] {
  fn(input) {
    let { chars, row, col } = input
    match chars {
      [x, .. chars] if f(x) =>
        if x == '\n' {
          (x, Input::{ chars, row: row + 1, col: 0 })
        } else {
          (x, Input::{ ..input, chars, col: col + 1 })
        }
      _ => raise Expect(row~, col~, "")
    }
  }
}

///|
pub fn[A] Parser::eof(x : A) -> Parser[A] {
  fn(input) {
    let { chars, row, col } = input
    match chars {
      [] => (x, input)
      _ => raise Expect(row~, col~, "eof")
    }
  }
}

///|
pub fn Parser::any(input : Input) -> (Char, Input)!ParseError {
  satisfy(fn { _ => true })(input)
}

///|
pub fn[A] Parser::label(x : Parser[A], s : String) -> Parser[A] {
  fn(input) {
    try x(input) catch {
      Expect(row~, col~, _) => raise Expect(row~, col~, s)
      Many([Expect(row~, col~, _), ..]) => raise Expect(row~, col~, s)
      Many(_) => panic()
    }
  }
}

///|
pub fn Parser::char(ch : Char) -> Parser[Char] {
  satisfy(fn { c => c == ch }).label(ch.to_string())
}

///|
pub fn Parser::string(str : String) -> Parser[String] {
  fn(input) {
    guard not(str.contains_char('\n')) else { panic() }
    let { chars, row, col } = input
    let len = str.length()
    guard chars.length() >= len && chars.view(end_offset=len) == str else {
      raise Expect(row~, col~, str)
    }
    (str, Input::{ ..input, chars: chars.view(start_offset=len), col: len })
  }
}

///|
pub fn[A, B] Parser::discard_left(self : Parser[A], y : Parser[B]) -> Parser[B] {
  self.bind(fn { _ => y })
}

///|
pub fn[A, B] Parser::discard_right(
  self : Parser[A],
  y : Parser[B]
) -> Parser[A] {
  self.bind(fn { r => y.bind(fn { _ => pure(r) }) })
}

///|
pub fn[A, B, C] Parser::between(
  self : Parser[A],
  open~ : Parser[B],
  close~ : Parser[C]
) -> Parser[A] {
  open.discard_left(self).discard_right(close)
}

///|
pub fn Parser::one_of(xs : String) -> Parser[Char] {
  satisfy(String::contains_char(xs, _)) |> label("one of \{xs.iter()}}")
}

///|
pub fn Parser::none_of(xs : String) -> Parser[Char] {
  satisfy(fn { ch => not(String::contains_char(xs, ch)) })
  |> label("none of \{xs.iter()}}")
}

///|
pub fn[A] foldl1(x : Parser[A], f : Parser[(A, A) -> A]) -> Parser[A] {
  fn go(a) {
    let acc = f.bind(fn { f => x.bind(fn { b => go(f(a, b)) }) })
    acc | pure(a)
  }

  x.bind(go)
}

///|
pub fn[A, B] Parser::map(self : Parser[A], f : (A) -> B) -> Parser[B] {
  self.bind(fn { x => pure(f(x)) })
}

///|
pub fn[A] Parser::parens(self : Parser[A]) -> Parser[A] {
  self.between(open=char('('), close=char(')'))
}

///|
pub fn Parser::digit(input : Input) -> (Char, Input)!ParseError {
  satisfy(Char::is_ascii_digit)(input)
}

///|
fnalias Parser::(
  any,
  between,
  bind,
  char,
  discard_left,
  discard_right,
  eof,
  label,
  map,
  none_of,
  one_of,
  parens,
  pure,
  run,
  satisfy,
  string,
  digit
)

///|
test {
  let input = Input::new("123456")
  let digit = map(digit, fn { ch => ch.to_int() - '0'.to_int() })
  let integer = foldl1(digit, pure(fn { acc, x => acc * 10 + x }))
  inspect(integer.run(input), content="123456")
  let add = char('+') |> discard_left(pure(Int::op_add))
  let sub = char('-') |> discard_left(pure(Int::op_sub))
  let mul = char('*') |> discard_left(pure(Int::op_mul))
  let div = char('/') |> discard_left(pure(Int::op_div))
  fn expr(input) -> (Int, Input)!ParseError {
    foldl1(term, add | sub)(input)
  }

  fn term(input) -> (Int, Input)!ParseError {
    foldl1(factor, mul | div)(input)
  }

  fn factor(input) -> (Int, Input)!ParseError {
    (Parser(expr).parens() | integer)(input)
  }

  let input = Input::new("(1+2)*3")
  inspect(Parser(expr).run(input), content="9")
  inspect(Parser(expr).run(Input::new("3*3+4*4")), content="25")
}

///|
test "or" {
  let x = char('x')
  let y = char('y')
  let parse = x | y |> label("x or y")
  let input = Input::new("x")
  inspect(
    try? parse(input),
    content=
      #|Ok(('x', {chars: "", row: 0, col: 1}))
    ,
  )
  inspect(
    try? parse(Input::new("_")),
    content=
      #|Err(Expect(row=0, col=0, "x or y"))
    ,
  )
}

///|
test "error" {
  let parse = char('x')
  let input = Input::new("_")
  inspect(
    try? parse(input),
    content=
      #|Err(Expect(row=0, col=0, "x"))
    ,
  )
  inspect(
    try? label(parse, "?")(input),
    content=
      #|Err(Expect(row=0, col=0, "?"))
    ,
  )
}
