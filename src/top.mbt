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
pub typealias Parser[A] = (Input) -> (A, Input)!ParseError

///|
pub fn[A, B] bind(x : Parser[A], f : (A) -> Parser[B]) -> Parser[B] {
  fn(input) {
    let (v, rest) = x(input)
    f(v)(rest)
  }
}

///|
pub fn[A] pure(x : A) -> Parser[A] {
  fn(input) { (x, input) }
}

///|
pub fn[A] or(x : Parser[A], y : Parser[A]) -> Parser[A] {
  fn(input) {
    try x(input) catch {
      e =>
        try y(input) catch {
          e_ => raise Many([e, e_])
        }
    }
  }
}

///|
pub fn satisfy(f : (Char) -> Bool) -> Parser[Char] {
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
pub fn[A] eof(x : A) -> Parser[A] {
  fn(input) {
    let { chars, row, col } = input
    match chars {
      [] => (x, input)
      _ => raise Expect(row~, col~, "eof")
    }
  }
}

///|
pub fn any(input : Input) -> (Char, Input)!ParseError {
  satisfy(fn { _ => true })(input)
}

///|
pub fn[A] label(x : Parser[A], s : String) -> Parser[A] {
  fn(input) {
    try x(input) catch {
      Expect(row~, col~, _) => raise Expect(row~, col~, s)
      Many([Expect(row~, col~, _), ..]) => raise Expect(row~, col~, s)
      Many(_) => panic()
    }
  }
}

///|
pub fn char(ch : Char) -> Parser[Char] {
  satisfy(fn { c => c == ch }) |> label(ch.to_string())
}

///|
pub fn string(str : String) -> Parser[String] {
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
pub fn[A, B] discard_left(x : Parser[A], y : Parser[B]) -> Parser[B] {
  x |> bind(fn { _ => y })
}

///|
pub fn[A, B] discard_right(x : Parser[A], y : Parser[B]) -> Parser[A] {
  x |> bind(fn { r => y |> bind(fn { _ => pure(r) }) })
}

///|
pub fn[A, B, C] between(
  x : Parser[A],
  open~ : Parser[B],
  close~ : Parser[C]
) -> Parser[A] {
  open |> discard_left(x) |> discard_right(close)
}

///|
pub fn one_of(xs : String) -> Parser[Char] {
  satisfy(String::contains_char(xs, _)) |> label("one of \{xs.iter()}}")
}

///|
pub fn none_of(xs : String) -> Parser[Char] {
  satisfy(fn { ch => not(String::contains_char(xs, ch)) })
  |> label("none of \{xs.iter()}}")
}

///|
pub fn[A] foldl1(x : Parser[A], f : Parser[(A, A) -> A]) -> Parser[A] {
  fn go(a) {
    let acc = f |> bind(fn { f => x |> bind(fn { b => go(f(a, b)) }) })
    or(acc, pure(a))
  }

  x |> bind(go)
}

///|
pub fn[A, B] map(x : Parser[A], f : (A) -> B) -> Parser[B] {
  x |> bind(fn { x => pure(f(x)) })
}

///|
pub fn[A] parens(x : Parser[A]) -> Parser[A] {
  between(x, open=char('('), close=char(')'))
}

///|
fn digit(input : Input) -> (Char, Input)!ParseError {
  satisfy(Char::is_ascii_digit)(input)
}

///|
test {
  let input = Input::new("123456")
  let digit = map(digit, fn { ch => ch.to_int() - '0'.to_int() })
  let integer = foldl1(digit, pure(fn { acc, x => acc * 10 + x }))
  inspect(
    try? integer(input),
    content=
      #|Ok((123456, {chars: "", row: 0, col: 6}))
    ,
  )
  let add = char('+') |> discard_left(pure(Int::op_add))
  let sub = char('-') |> discard_left(pure(Int::op_sub))
  let mul = char('*') |> discard_left(pure(Int::op_mul))
  let div = char('/') |> discard_left(pure(Int::op_div))
  fn expr(input) -> (Int, Input)!ParseError {
    foldl1(term, or(add, sub))(input)
  }

  fn term(input) -> (Int, Input)!ParseError {
    foldl1(factor, or(mul, div))(input)
  }

  fn factor(input) -> (Int, Input)!ParseError {
    or(parens(expr), integer)(input)
  }

  let input = Input::new("(1+2)*3")
  inspect(
    try? expr(input),
    content=
      #|Ok((9, {chars: "", row: 0, col: 7}))
    ,
  )
}

///|
test "or" {
  let x = char('x')
  let y = char('y')
  let parse = or(x, y) |> label("x or y")
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
