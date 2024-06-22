import gleam/float
import gleam/int
import gleam/regex.{type Regex}
import gleam/result
import gleam/string

pub type ParserPosition {
  ParserPosition(row: Int, col: Int)
}

pub type Parser(a) {
  Parser(tokens: List(String), pos: ParserPosition, value: a)
}

pub type ExpectedToken {
  Literal(String)
  Pattern(String)
}

pub type ParserFailure {
  UnexpectedToken(
    expected_token: ExpectedToken,
    actual_token: String,
    pos: ParserPosition,
  )
  UnexpectedEof(expected_token: ExpectedToken, pos: ParserPosition)
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

pub fn ignore_float(value: a, _: Float) -> a {
  value
}

pub fn parse(
  input: String,
  initial_value: a,
  parser: ParserCombinatorCallback(a),
) -> Result(a, ParserFailure) {
  use parser <- result.try(
    Parser(input |> string.split(""), ParserPosition(0, 0), initial_value)
    |> Ok()
    |> parser(),
  )

  Ok(parser.value)
}

pub fn token(
  prev: ParserResult(a),
  token: String,
  to: ParserMapperCallback(a, String),
) -> ParserResult(a) {
  use previous_parser <- result.try(prev)

  use token_parser <- result.try(do_token(
    previous_parser |> from(""),
    token |> string.split(""),
  ))

  token_parser |> from(to(previous_parser.value, token_parser.value))
}

pub fn optional(
  prev: ParserResult(a),
  parser: ParserCombinatorCallback(a),
) -> ParserResult(a) {
  case parser(prev) {
    Error(_) -> prev
    result -> result
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
    [token, ..rest]
      if token == "0"
      || token == "1"
      || token == "2"
      || token == "3"
      || token == "4"
      || token == "5"
      || token == "6"
      || token == "7"
      || token == "8"
      || token == "9"
    ->
      Parser(rest, increment_parser_position(previous_parser.pos, token), token)
      |> Ok()
      |> do_integer()
    [token, ..rest] if token == "+" || token == "-" ->
      case rest {
        [] ->
          UnexpectedEof(
            digit,
            increment_parser_position(previous_parser.pos, token),
          )
          |> Error()
        tokens ->
          Parser(
            tokens,
            increment_parser_position(previous_parser.pos, token),
            token,
          )
          |> Ok()
          |> do_integer()
      }
    [token, ..] -> UnexpectedToken(digit, token, previous_parser.pos) |> Error()
    [] -> UnexpectedEof(digit, previous_parser.pos) |> Error()
  })

  case int.parse(integer_parser.value) {
    Ok(integer) ->
      Parser(
        integer_parser.tokens,
        integer_parser.pos,
        to(previous_parser.value, integer),
      )
      |> Ok()
    Error(_) ->
      UnexpectedToken(digit, integer_parser.value, integer_parser.pos)
      |> Error()
  }
}

pub fn float(
  prev: ParserResult(a),
  to: ParserMapperCallback(a, Float),
) -> ParserResult(a) {
  use previous_parser <- result.try(prev)

  use float_parser <- result.try(case previous_parser.tokens {
    [token, ..rest]
      if token == "0"
      || token == "1"
      || token == "2"
      || token == "3"
      || token == "4"
      || token == "5"
      || token == "6"
      || token == "7"
      || token == "8"
      || token == "9"
      || token == "."
    ->
      Parser(rest, increment_parser_position(previous_parser.pos, token), token)
      |> Ok()
      |> do_float(False)
    [token, ..rest] if token == "+" || token == "-" ->
      case rest {
        [] ->
          UnexpectedEof(
            digit_or_decimal_point,
            increment_parser_position(previous_parser.pos, token),
          )
          |> Error()
        tokens ->
          Parser(
            tokens,
            increment_parser_position(previous_parser.pos, token),
            token,
          )
          |> Ok()
          |> do_float(False)
      }
    [token, ..] ->
      UnexpectedToken(digit_or_decimal_point, token, previous_parser.pos)
      |> Error()
    [] -> UnexpectedEof(digit_or_decimal_point, previous_parser.pos) |> Error()
  })

  case
    float_parser.value
    |> add_integral_part_to_string_float_value()
    |> float.parse()
  {
    Ok(float) ->
      Parser(
        float_parser.tokens,
        float_parser.pos,
        to(previous_parser.value, float),
      )
      |> Ok()
    Error(_) ->
      UnexpectedToken(digit, float_parser.value, float_parser.pos) |> Error()
  }
}

pub fn until(
  prev: ParserResult(a),
  token: String,
  to: ParserMapperCallback(a, String),
) -> ParserResult(a) {
  use previous_parser <- result.try(prev)

  use until_parser <- result.try(do_until(
    previous_parser |> from(""),
    token,
    token |> string.split(""),
  ))

  until_parser |> from(to(previous_parser.value, until_parser.value))
}

pub fn skip_until(prev: ParserResult(a), token: String) -> ParserResult(a) {
  do_skip_until(prev, token, token |> string.split(""))
}

pub fn repeat(
  prev: ParserResult(List(a)),
  initial_value: a,
  parser: ParserCombinatorCallback(a),
) -> ParserResult(List(a)) {
  do_repeat(prev, initial_value, parser)
}

pub fn whitespace(
  prev: ParserResult(a),
  to: ParserMapperCallback(a, String),
) -> ParserResult(a) {
  use previous_parser <- result.try(prev)

  use whitespace_parser <- result.try(do_whitespace(previous_parser |> from("")))

  whitespace_parser
  |> from(to(previous_parser.value, whitespace_parser.value))
}

pub fn skip_whitespace(prev: ParserResult(a)) -> ParserResult(a) {
  use parser <- result.try(prev)

  case parser.tokens {
    [] -> prev
    [token, ..rest] ->
      case whitespace_pattern() |> regex.check(token) {
        False -> prev
        True ->
          Parser(
            rest,
            increment_parser_position(parser.pos, token),
            parser.value,
          )
          |> Ok()
          |> skip_whitespace()
      }
  }
}

const digit = Pattern("[0-9]")

const digit_or_decimal_point = Pattern("[0-9.]")

fn from(prev: Parser(a), initial_value: b) -> ParserResult(b) {
  Parser(prev.tokens, prev.pos, initial_value) |> Ok()
}

fn do_token(
  prev: ParserResult(String),
  expected_tokens: List(String),
) -> ParserResult(String) {
  use parser <- result.try(prev)

  case expected_tokens {
    [] -> prev
    [expected_token, ..expected_rest] ->
      case parser.tokens {
        [] ->
          UnexpectedEof(
            Literal(parser.value <> string.join(expected_tokens, "")),
            parser.pos,
          )
          |> Error()
        [actual_token, ..] if expected_token != actual_token ->
          UnexpectedToken(
            Literal(parser.value <> string.join(expected_tokens, "")),
            parser.value <> actual_token,
            parser.pos,
          )
          |> Error()
        [actual_token, ..actual_rest] ->
          Parser(
            actual_rest,
            increment_parser_position(parser.pos, actual_token),
            parser.value <> actual_token,
          )
          |> Ok()
          |> do_token(expected_rest)
      }
  }
}

fn do_integer(prev: ParserResult(String)) -> ParserResult(String) {
  use parser <- result.try(prev)

  let assert Ok(pattern) = regex.from_string("^[0-9]$")

  case parser.tokens {
    [] -> prev
    [token, ..rest] ->
      case regex.check(pattern, token) {
        False -> prev
        True ->
          Parser(
            rest,
            increment_parser_position(parser.pos, token),
            parser.value <> token,
          )
          |> Ok()
          |> do_integer()
      }
  }
}

fn do_float(
  prev: ParserResult(String),
  after_fraction: Bool,
) -> ParserResult(String) {
  use parser <- result.try(prev)

  let assert Ok(pattern) = regex.from_string("^[0-9.]$")

  case parser.tokens {
    [] -> prev
    [".", ..] if after_fraction -> prev
    [token, ..rest] ->
      case regex.check(pattern, token) {
        False -> prev
        True ->
          Parser(
            rest,
            increment_parser_position(parser.pos, token),
            parser.value <> token,
          )
          |> Ok()
          |> do_float(case token {
            "." -> True
            _ if after_fraction -> True
            _ -> False
          })
      }
  }
}

fn do_until(
  prev: ParserResult(String),
  until_token: String,
  expected_tokens: List(String),
) -> ParserResult(String) {
  use parser <- result.try(prev)

  case expected_tokens {
    [] -> prev
    [expected_token, ..] ->
      case parser.tokens {
        [] -> UnexpectedEof(Literal(until_token), parser.pos) |> Error()
        [actual_token, ..actual_rest] if actual_token == expected_token ->
          case
            parser.tokens
            |> string.join("")
            |> string.starts_with(until_token)
          {
            True -> prev
            False ->
              Parser(
                actual_rest,
                increment_parser_position(parser.pos, actual_token),
                parser.value <> actual_token,
              )
              |> Ok()
              |> do_until(until_token, expected_tokens)
          }
        [actual_token, ..actual_rest] ->
          Parser(
            actual_rest,
            increment_parser_position(parser.pos, actual_token),
            parser.value <> actual_token,
          )
          |> Ok()
          |> do_until(until_token, expected_tokens)
      }
  }
}

fn do_skip_until(
  prev: ParserResult(a),
  until_token: String,
  expected_tokens: List(String),
) -> ParserResult(a) {
  use parser <- result.try(prev)

  case expected_tokens {
    [] -> prev
    [expected_token, ..] ->
      case parser.tokens {
        [] -> UnexpectedEof(Literal(until_token), parser.pos) |> Error()
        [actual_token, ..actual_rest] if actual_token == expected_token ->
          case
            parser.tokens
            |> string.join("")
            |> string.starts_with(until_token)
          {
            True -> prev
            False ->
              Parser(
                actual_rest,
                increment_parser_position(parser.pos, actual_token),
                parser.value,
              )
              |> Ok()
              |> do_skip_until(until_token, expected_tokens)
          }
        [actual_token, ..actual_rest] ->
          Parser(
            actual_rest,
            increment_parser_position(parser.pos, actual_token),
            parser.value,
          )
          |> Ok()
          |> do_skip_until(until_token, expected_tokens)
      }
  }
}

fn do_repeat(
  prev: ParserResult(List(a)),
  initial_value: a,
  parser: ParserCombinatorCallback(a),
) -> ParserResult(List(a)) {
  use previous_parser <- result.try(prev)

  case parser(previous_parser |> from(initial_value)) {
    Error(_) -> prev
    Ok(repeat_parser) ->
      do_repeat(
        repeat_parser |> from([repeat_parser.value, ..previous_parser.value]),
        initial_value,
        parser,
      )
  }
}

fn do_whitespace(prev: ParserResult(String)) -> ParserResult(String) {
  use parser <- result.try(prev)

  case parser.tokens {
    [] -> prev
    [token, ..rest] ->
      case whitespace_pattern() |> regex.check(token) {
        False -> prev
        True ->
          Parser(
            rest,
            increment_parser_position(parser.pos, token),
            parser.value <> token,
          )
          |> Ok()
          |> do_whitespace()
      }
  }
}

fn add_integral_part_to_string_float_value(float_as_string: String) -> String {
  case float_as_string |> string.split("") {
    [".", ..rest] -> "0." <> string.join(rest, "")
    ["-", ..rest] ->
      case rest {
        [".", ..fraction] -> "-0." <> string.join(fraction, "")
        float -> "-" <> string.join(float, "")
      }
    float -> float |> string.join("")
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

fn whitespace_pattern() -> Regex {
  let assert Ok(pattern) = regex.from_string("^\\s$")

  pattern
}
