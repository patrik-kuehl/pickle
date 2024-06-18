import gleam/float
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

pub fn ignore_float(value: a, _: Float) -> a {
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

  use token_parser <- result.try(do_token(
    Ok(Parser(previous_parser.tokens, previous_parser.pos, "")),
    token |> string.split(""),
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
      do_integer(
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
          do_integer(
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
      do_float(
        Ok(Parser(
          rest,
          increment_parser_position(previous_parser.pos, token),
          token,
        )),
        False,
      )
    ["-", ..rest] ->
      case rest {
        [] ->
          Error(UnexpectedEof(
            "<float>",
            increment_parser_position(previous_parser.pos, "-"),
          ))
        tokens ->
          do_float(
            Ok(Parser(
              tokens,
              increment_parser_position(previous_parser.pos, "-"),
              "-",
            )),
            False,
          )
      }
    [token, ..] -> Error(UnexpectedToken("<float>", token, previous_parser.pos))
    [] -> Error(UnexpectedEof("<float>", previous_parser.pos))
  })

  case
    float_parser.value
    |> add_integral_part_to_string_float_value()
    |> float.parse()
  {
    Ok(float) ->
      Ok(Parser(
        float_parser.tokens,
        float_parser.pos,
        to(previous_parser.value, float),
      ))
    Error(_) ->
      Error(UnexpectedToken("<float>", float_parser.value, float_parser.pos))
  }
}

pub fn until(
  prev: ParserResult(a),
  token: String,
  to: ParserMapperCallback(a, String),
) -> ParserResult(a) {
  use previous_parser <- result.try(prev)

  use until_parser <- result.try(do_until(
    Ok(Parser(previous_parser.tokens, previous_parser.pos, "")),
    token,
    token |> string.split(""),
  ))

  Ok(Parser(
    until_parser.tokens,
    until_parser.pos,
    to(previous_parser.value, until_parser.value),
  ))
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
          Error(UnexpectedEof(
            parser.value <> string.join(expected_tokens, ""),
            parser.pos,
          ))
        [actual_token, ..] if expected_token != actual_token ->
          Error(UnexpectedToken(
            parser.value <> string.join(expected_tokens, ""),
            parser.value <> actual_token,
            parser.pos,
          ))
        [actual_token, ..actual_rest] ->
          do_token(
            Ok(Parser(
              actual_rest,
              increment_parser_position(parser.pos, actual_token),
              parser.value <> actual_token,
            )),
            expected_rest,
          )
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
          do_integer(
            Ok(Parser(
              rest,
              increment_parser_position(parser.pos, token),
              parser.value <> token,
            )),
          )
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
          do_float(
            Ok(Parser(
              rest,
              increment_parser_position(parser.pos, token),
              parser.value <> token,
            )),
            case token {
              "." -> True
              _ if after_fraction -> True
              _ -> False
            },
          )
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
        [] -> Error(UnexpectedEof(until_token, parser.pos))
        [actual_token, ..actual_rest] if actual_token == expected_token ->
          case
            parser.tokens
            |> string.join("")
            |> string.starts_with(until_token)
          {
            True -> prev
            False ->
              do_until(
                Ok(Parser(
                  actual_rest,
                  increment_parser_position(parser.pos, actual_token),
                  parser.value <> actual_token,
                )),
                until_token,
                expected_tokens,
              )
          }
        [actual_token, ..actual_rest] ->
          do_until(
            Ok(Parser(
              actual_rest,
              increment_parser_position(parser.pos, actual_token),
              parser.value <> actual_token,
            )),
            until_token,
            expected_tokens,
          )
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
        [] -> Error(UnexpectedEof(until_token, parser.pos))
        [actual_token, ..actual_rest] if actual_token == expected_token ->
          case
            parser.tokens
            |> string.join("")
            |> string.starts_with(until_token)
          {
            True -> prev
            False ->
              do_skip_until(
                Ok(Parser(
                  actual_rest,
                  increment_parser_position(parser.pos, actual_token),
                  parser.value,
                )),
                until_token,
                expected_tokens,
              )
          }
        [actual_token, ..actual_rest] ->
          do_skip_until(
            Ok(Parser(
              actual_rest,
              increment_parser_position(parser.pos, actual_token),
              parser.value,
            )),
            until_token,
            expected_tokens,
          )
      }
  }
}

fn do_repeat(
  prev: ParserResult(List(a)),
  initial_value: a,
  parser: ParserCombinatorCallback(a),
) -> ParserResult(List(a)) {
  use previous_parser <- result.try(prev)

  case
    parser(
      Ok(Parser(previous_parser.tokens, previous_parser.pos, initial_value)),
    )
  {
    Error(_) -> prev
    Ok(repeat_parser) ->
      do_repeat(
        Ok(
          Parser(repeat_parser.tokens, repeat_parser.pos, [
            repeat_parser.value,
            ..previous_parser.value
          ]),
        ),
        initial_value,
        parser,
      )
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
