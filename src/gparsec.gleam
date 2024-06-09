import gleam/string

pub type ParserPosition {
  ParserPosition(row: Int, col: Int)
}

pub type Parser(a) {
  Parser(tokens: List(String), pos: ParserPosition, value: a)
}

pub type ParserFailure {
  UnexpectedToken(
    expected_tokens: List(String),
    actual_token: String,
    pos: ParserPosition,
  )
  UnexpectedEof(expected_tokens: List(String), pos: ParserPosition)
}

pub type ParserResult(a) =
  Result(Parser(a), ParserFailure)

pub fn input(tokens tokens: String, initial_value value: a) -> ParserResult(a) {
  Ok(Parser(tokens |> string.split(""), ParserPosition(0, 0), value))
}
