# illusory0x0/simple_parserc

Parser combinators with backtracking and row/column errors.

Create parsers with `Parser::char`, `Parser::string`, `Parser::satisfy`, or the
`Parser` constructor, then combine them with `bind`, `map`, `foldl1`, and `|`.
`parser.run(input)` returns the parsed value. To retain the remaining input,
call the parser's function field: `(parser.0)(input)`.

The current MoonBit port replaces the removed callable-wrapper type syntax with
`struct Parser[A]((Input) -> (A, Input) raise ParseError)`. Existing `.run` calls
keep their behavior; direct `parser(input)` calls must migrate to
`(parser.0)(input)`, and raw function values must be wrapped with `Parser(...)`.

Position behavior remains unchanged: character parsers advance by one character,
while `string` assigns the string's UTF-16 length to the column. Backtracking
restarts each alternative from the same input. Existing `Input` and `ParseError`
`Show` formatting is retained alongside `Debug` implementations.

Run `moon check --target all --deny-warn` and `moon test --target all` to validate.
CI checks rolling `latest` and `pre-release` toolchains every Friday and on pushes
and pull requests, across wasm, wasm-gc, JavaScript, and native backends.
