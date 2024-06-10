import gleam/result
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

pub type ParserMapperCallback(a, b) =
  fn(a, b) -> a

pub type ParserCombinatorCallback(a) =
  fn(ParserResult(a)) -> ParserResult(a)

pub fn ignore_token(value: a, _: String) -> a {
  value
}

pub fn input(tokens: String, initial_value: a) -> ParserResult(a) {
  Ok(Parser(tokens |> string.split(""), ParserPosition(0, 0), initial_value))
}

pub fn token(
  prev: ParserResult(a),
  tokens: String,
  to: ParserMapperCallback(a, String),
) -> ParserResult(a) {
  use previous_parser <- result.try(prev)

  use token_parser <- result.try(token_internal(
    Ok(Parser(previous_parser.tokens, previous_parser.pos, "")),
    tokens |> string.split(""),
    "",
    tokens,
  ))

  Ok(Parser(
    token_parser.tokens,
    token_parser.pos,
    to(previous_parser.value, token_parser.value),
  ))
}

pub fn optional(
  prev: ParserResult(a),
  parser: ParserCombinatorCallback(a),
) -> ParserResult(a) {
  case parser(prev) {
    Error(_) -> prev
    Ok(parser) -> Ok(parser)
  }
}

fn token_internal(
  prev: ParserResult(String),
  unprocessed_tokens: List(String),
  processed_tokens: String,
  expected_tokens: String,
) -> ParserResult(String) {
  case unprocessed_tokens {
    [] -> prev
    [c, ..rest] ->
      single_token(prev, c, processed_tokens, expected_tokens)
      |> token_internal(rest, processed_tokens <> c, expected_tokens)
  }
}

fn single_token(
  prev: ParserResult(String),
  token: String,
  processed_tokens: String,
  expected_tokens: String,
) -> ParserResult(String) {
  use parser <- result.try(prev)

  case parser.tokens {
    [c, ..rest] if c == token ->
      Ok(Parser(
        rest,
        increment_parser_position(parser.pos, c),
        parser.value <> c,
      ))
    [c, ..] ->
      Error(UnexpectedToken(
        [expected_tokens],
        processed_tokens <> c,
        parser.pos,
      ))
    [] -> Error(UnexpectedEof([expected_tokens], parser.pos))
  }
}

fn increment_parser_position(
  prev: ParserPosition,
  recent_token: String,
) -> ParserPosition {
  case recent_token {
    "\n" -> ParserPosition(prev.row + 1, 0)
    _ -> ParserPosition(prev.row, prev.col + 1)
  }
}
