///|
test "public parser construction and foldl1 alias" {
  let digit = @simple_parserc.Parser(@simple_parserc.Parser::digit).map(ch => {
    ch.to_int() - '0'
  })
  let integer = @simple_parserc.foldl1(
    digit,
    @simple_parserc.Parser::pure((acc, x) => acc * 10 + x),
  )
  assert_eq(integer.run(@simple_parserc.Input::new("123")), 123)
  let (value, rest) = (integer.0)(@simple_parserc.Input::new("42x"))
  assert_eq(value, 42)
  assert_eq(rest.chars, "x")
}
