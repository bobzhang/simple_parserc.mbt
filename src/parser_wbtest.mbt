///|
fn expr(input : Input) -> (Int32, Input) raise ParseError {
  let add = Parser::char('+').discard_left(Parser::pure(Int32::add))
  let sub = Parser::char('-').discard_left(Parser::pure(Int32::sub))
  (Parser(term).foldl1(add | sub).0)(input)
}

///|
fn term(input : Input) -> (Int32, Input) raise ParseError {
  let mul = Parser::char('*').discard_left(Parser::pure(Int32::mul))
  let div = Parser::char('/').discard_left(Parser::pure(Int32::div))
  (Parser(factor).foldl1(mul | div).0)(input)
}

///|
fn factor(input : Input) -> (Int32, Input) raise ParseError {
  let digit = Parser(Parser::digit).map(ch => ch.to_int() - '0')
  let integer = digit.foldl1(Parser::pure((acc, x) => acc * 10 + x))
  ((Parser(expr).parens() | integer).0)(input)
}

///|
test {
  let input = Input::new("123456")
  let digit = Parser(Parser::digit).map(ch => ch.to_int() - '0')
  let integer = digit.foldl1(Parser::pure((acc, x) => acc * 10 + x))
  inspect(integer.run(input), content="123456")
  let input = Input::new("(1+2)*3")
  inspect(Parser(expr).run(input), content="9")
  inspect(Parser(expr).run(Input::new("3*3+4*4")), content="25")
}

///|
test "or" {
  let x = Parser::char('x')
  let y = Parser::char('y')
  let parse = (x | y).label("x or y")
  let input = Input::new("x")
  debug_inspect(
    Ok((parse.0)(input)) catch {
      e => Err(e)
    },
    content=(
      #|Ok(('x', { chars: <StringView: "">, row: 0, col: 1 }))
    ),
  )
  debug_inspect(
    Ok((parse.0)(Input::new("_"))) catch {
      e => Err(e)
    },
    content=(
      #|Err(Expect(row=0, col=0, "x or y"))
    ),
  )
}

///|
test "error" {
  let parse = Parser::char('x')
  let input = Input::new("_")
  debug_inspect(
    Ok((parse.0)(input)) catch {
      e => Err(e)
    },
    content=(
      #|Err(Expect(row=0, col=0, "x"))
    ),
  )
  debug_inspect(
    Ok((parse.label("?").0)(input)) catch {
      e => Err(e)
    },
    content=(
      #|Err(Expect(row=0, col=0, "?"))
    ),
  )
}

///|
test "backtracking restores input and newline positions" {
  let left = Parser::char('a').discard_left(Parser::char('x'))
  let right = Parser::char('a').discard_left(Parser::char('\n'))
  let (value, rest) = ((left | right).0)(Input::new("a\nz"))
  assert_eq(value, '\n')
  assert_eq(rest.chars, "z")
  assert_eq(rest.row, 1)
  assert_eq(rest.col, 0)
}

///|
test "unicode character and string parsing" {
  let (value, rest) = (Parser::char('😀').0)(Input::new("😀x"))
  assert_eq(value, '😀')
  assert_eq(rest.chars, "x")
  assert_eq(rest.col, 1)
  let (value, rest) = (Parser::string("😀").0)(Input::new("😀x"))
  assert_eq(value, "😀")
  assert_eq(rest.chars, "x")
  assert_eq(rest.col, 2)
}

///|
test "string keeps legacy absolute column behavior" {
  let parse = Parser::char('a').discard_left(Parser::string("bc"))
  let (value, rest) = (parse.0)(Input::new("abcd"))
  assert_eq(value, "bc")
  assert_eq(rest.chars, "d")
  // Existing string parsers assign the consumed string length to col.
  assert_eq(rest.col, 2)
}

///|
test "eof and nested alternative errors" {
  assert_eq(Parser::eof(42).run(Input::new("")), 42)
  try Parser::eof(42).run(Input::new("x")) catch {
    Expect(row=0, col=0, "eof") => ()
    _ => fail("expected eof error")
  } noraise {
    _ => fail("expected failure on remaining input")
  }
  let parse = Parser::char('a') | Parser::char('b') | Parser::char('c')
  try parse.run(Input::new("x")) catch {
    Many(
      [
        Many([Expect(row=0, col=0, "a"), Expect(row=0, col=0, "b")]),
        Expect(row=0, col=0, "c"),
      ],
    ) => ()
    _ => fail("expected nested errors")
  } noraise {
    _ => fail("expected alternative failure")
  }
}

///|
test "public Show output stays compatible" {
  inspect(Input::new("x"), content="{chars: \"x\", row: 0, col: 0}")
  let error : ParseError = Many([Expect(row=2, col=3, "x")])
  inspect(error, content="Many([Expect(row=2, col=3, \"x\")])")
}
