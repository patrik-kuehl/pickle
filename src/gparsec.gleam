import gleam/int
import gleam/regex
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
    expected_token: String,
    actual_token: String,
    pos: ParserPosition,
  )
  UnexpectedEof(expected_token: String, pos: ParserPosition)
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

pub fn ignore_integer(value: a, _: Int) -> a {
  value
}

pub fn input(tokens: String, initial_value: a) -> ParserResult(a) {
  Ok(Parser(tokens |> string.split(""), ParserPosition(0, 0), initial_value))
}

pub fn token(
  prev: ParserResult(a),
  token: String,
  to: ParserMapperCallback(a, String),
) -> ParserResult(a) {
  use previous_parser <- result.try(prev)

  use token_parser <- result.try(token_internal(
    Ok(Parser(previous_parser.tokens, previous_parser.pos, "")),
    token |> string.split(""),
    "",
    token,
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

pub fn many(
  prev: ParserResult(a),
  parser: ParserCombinatorCallback(a),
) -> ParserResult(a) {
  case parser(prev) {
    Error(_) -> prev
    result -> many(result, parser)
  }
}

pub fn integer(
  prev: ParserResult(a),
  to: ParserMapperCallback(a, Int),
) -> ParserResult(a) {
  use previous_parser <- result.try(prev)

  use integer_parser <- result.try(case previous_parser.tokens {
    [c, ..rest]
      if c == "0"
      || c == "1"
      || c == "2"
      || c == "3"
      || c == "4"
      || c == "5"
      || c == "6"
      || c == "7"
      || c == "8"
      || c == "9"
    ->
      integer_internal(
        Ok(Parser(rest, increment_parser_position(previous_parser.pos, c), c)),
      )
    ["-", ..rest] ->
      case rest {
        [] ->
          Error(UnexpectedEof(
            "<integer>",
            increment_parser_position(previous_parser.pos, "-"),
          ))
        tokens ->
          integer_internal(
            Ok(Parser(
              tokens,
              increment_parser_position(previous_parser.pos, "-"),
              "-",
            )),
          )
      }
    [c, ..] -> Error(UnexpectedToken("<integer>", c, previous_parser.pos))
    [] -> Error(UnexpectedEof("<integer>", previous_parser.pos))
  })

  case int.parse(integer_parser.value) {
    Ok(integer) ->
      Ok(Parser(
        integer_parser.tokens,
        integer_parser.pos,
        to(previous_parser.value, integer),
      ))
    Error(_) ->
      Error(UnexpectedToken(
        "<integer>",
        integer_parser.value,
        integer_parser.pos,
      ))
  }
}

fn token_internal(
  prev: ParserResult(String),
  unprocessed_tokens: List(String),
  processed_tokens: String,
  expected_token: String,
) -> ParserResult(String) {
  case unprocessed_tokens {
    [] -> prev
    [c, ..rest] ->
      single_token(prev, c, processed_tokens, expected_token)
      |> token_internal(rest, processed_tokens <> c, expected_token)
  }
}

fn single_token(
  prev: ParserResult(String),
  token: String,
  processed_tokens: String,
  expected_token: String,
) -> ParserResult(String) {
  use parser <- result.try(prev)

  case parser.tokens {
    [] -> Error(UnexpectedEof(expected_token, parser.pos))
    [c, ..] if c != token ->
      Error(UnexpectedToken(expected_token, processed_tokens <> c, parser.pos))
    [c, ..rest] ->
      Ok(Parser(
        rest,
        increment_parser_position(parser.pos, c),
        parser.value <> c,
      ))
  }
}

fn integer_internal(prev: ParserResult(String)) -> ParserResult(String) {
  use parser <- result.try(prev)

  let assert Ok(pattern) = regex.from_string("^[0-9]$")

  case parser.tokens {
    [] -> prev
    [c, ..rest] ->
      case regex.check(pattern, c) {
        False -> prev
        True ->
          integer_internal(
            Ok(Parser(
              rest,
              increment_parser_position(parser.pos, c),
              parser.value <> c,
            )),
          )
      }
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
