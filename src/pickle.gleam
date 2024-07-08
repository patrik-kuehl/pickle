import gleam/float
import gleam/int
import gleam/regex
import gleam/string

pub type ParserPosition {
  ParserPosition(row: Int, col: Int)
}

pub opaque type Parser(a) {
  Parser(tokens: List(String), pos: ParserPosition, value: a)
}

pub type ExpectedToken {
  Literal(String)
  Pattern(String)
  Eof
}

pub type ParserFailure(a) {
  UnexpectedToken(
    expected_token: ExpectedToken,
    actual_token: String,
    pos: ParserPosition,
  )
  UnexpectedEof(expected_token: ExpectedToken, pos: ParserPosition)
  GuardError(error: a, pos: ParserPosition)
}

pub fn ignore_string(value: a, _: String) -> a {
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
  combinator: fn(Parser(a)) -> Result(Parser(b), ParserFailure(c)),
) -> Result(b, ParserFailure(c)) {
  case
    Parser(string.to_graphemes(input), ParserPosition(0, 0), initial_value)
    |> combinator()
  {
    Error(failure) -> Error(failure)
    Ok(parser) -> Ok(parser.value)
  }
}

pub fn then(
  prev: fn(Parser(a)) -> Result(Parser(b), ParserFailure(c)),
  then: fn(Parser(b)) -> Result(Parser(d), ParserFailure(c)),
) -> fn(Parser(a)) -> Result(Parser(d), ParserFailure(c)) {
  fn(parser) {
    case prev(parser) {
      Error(failure) -> Error(failure)
      Ok(next_parser) -> then(next_parser)
    }
  }
}

pub fn guard(
  predicate: fn(a) -> Bool,
  error: b,
) -> fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)) {
  fn(parser) {
    let Parser(_, pos, value) = parser

    case predicate(value) {
      False -> GuardError(error, pos) |> Error()
      True -> Ok(parser)
    }
  }
}

pub fn map(
  mapper: fn(a) -> b,
) -> fn(Parser(a)) -> Result(Parser(b), ParserFailure(c)) {
  fn(parser) {
    let Parser(tokens, pos, value) = parser

    Parser(tokens, pos, mapper(value)) |> Ok()
  }
}

pub fn string(
  expected: String,
  mapper: fn(a, String) -> a,
) -> fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)) {
  fn(parser) {
    let Parser(tokens, pos, value) = parser

    case
      Parser(tokens, pos, "")
      |> Ok()
      |> do_string(string.to_graphemes(expected))
    {
      Error(failure) -> Error(failure)
      Ok(token_parser) ->
        Parser(
          token_parser.tokens,
          token_parser.pos,
          mapper(value, token_parser.value),
        )
        |> Ok()
    }
  }
}

pub fn optional(
  combinator: fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)),
) -> fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)) {
  fn(parser) {
    case combinator(parser) {
      Error(_) -> Ok(parser)
      result -> result
    }
  }
}

pub fn many(
  initial_value: a,
  combinator: fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)),
  acc: fn(c, a) -> c,
) -> fn(Parser(c)) -> Result(Parser(c), ParserFailure(b)) {
  fn(parser) {
    parser
    |> Ok()
    |> do_many(initial_value, combinator, acc)
  }
}

pub fn integer(
  mapper: fn(a, Int) -> a,
) -> fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)) {
  fn(parser) {
    let Parser(tokens, pos, _) = parser

    case tokens {
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
        Parser(rest, increment_parser_position(pos, token), token)
        |> Ok()
        |> do_integer()
        |> parse_string_as_integer(parser, mapper)
      [token, ..rest] if token == "+" || token == "-" ->
        case rest {
          [] ->
            UnexpectedEof(
              Pattern(digit_pattern),
              increment_parser_position(pos, token),
            )
            |> Error()
          tokens ->
            Parser(tokens, increment_parser_position(pos, token), token)
            |> Ok()
            |> do_integer()
            |> parse_string_as_integer(parser, mapper)
        }
      [token, ..] ->
        UnexpectedToken(Pattern(digit_pattern), token, pos)
        |> Error()
      [] ->
        UnexpectedEof(Pattern(digit_pattern), pos)
        |> Error()
    }
  }
}

pub fn float(
  mapper: fn(a, Float) -> a,
) -> fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)) {
  fn(parser) {
    let Parser(tokens, pos, _) = parser

    case tokens {
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
        Parser(rest, increment_parser_position(pos, token), token)
        |> Ok()
        |> do_float(False)
        |> parse_string_as_float(parser, mapper)
      [token, ..rest] if token == "+" || token == "-" ->
        case rest {
          [] ->
            UnexpectedEof(
              Pattern(digit_or_decimal_point_pattern),
              increment_parser_position(pos, token),
            )
            |> Error()
          tokens ->
            Parser(tokens, increment_parser_position(pos, token), token)
            |> Ok()
            |> do_float(False)
            |> parse_string_as_float(parser, mapper)
        }
      [token, ..] ->
        UnexpectedToken(Pattern(digit_or_decimal_point_pattern), token, pos)
        |> Error()
      [] ->
        UnexpectedEof(Pattern(digit_or_decimal_point_pattern), pos)
        |> Error()
    }
  }
}

pub fn until(
  terminator: String,
  mapper: fn(a, String) -> a,
) -> fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)) {
  fn(parser) {
    let Parser(tokens, pos, value) = parser

    case
      Parser(tokens, pos, "")
      |> Ok()
      |> do_until(terminator, string.to_graphemes(terminator))
    {
      Error(failure) -> Error(failure)
      Ok(until_parser) ->
        Parser(
          until_parser.tokens,
          until_parser.pos,
          mapper(value, until_parser.value),
        )
        |> Ok()
    }
  }
}

pub fn skip_until(
  terminator: String,
) -> fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)) {
  fn(parser) {
    parser |> Ok() |> do_skip_until(terminator, string.to_graphemes(terminator))
  }
}

pub fn whitespace(
  mapper: fn(a, String) -> a,
) -> fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)) {
  fn(parser) {
    let Parser(tokens, pos, value) = parser

    case Parser(tokens, pos, "") |> Ok() |> do_whitespace() {
      Error(failure) -> Error(failure)
      Ok(whitespace_parser) ->
        Parser(
          whitespace_parser.tokens,
          whitespace_parser.pos,
          mapper(value, whitespace_parser.value),
        )
        |> Ok()
    }
  }
}

pub fn skip_whitespace() -> fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)) {
  fn(parser) {
    let Parser(tokens, pos, value) = parser

    case tokens {
      [] -> Ok(parser)
      [token, ..rest] ->
        case is_whitespace(token) {
          False -> Ok(parser)
          True ->
            Parser(rest, increment_parser_position(pos, token), value)
            |> skip_whitespace()
        }
    }
  }
}

pub fn one_of(
  combinators: List(fn(Parser(a)) -> Result(Parser(a), ParserFailure(b))),
) -> fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)) {
  fn(parser) { parser |> Ok() |> do_one_of(parser, combinators) }
}

pub fn return(value: a) -> fn(Parser(b)) -> Result(Parser(a), ParserFailure(c)) {
  fn(parser) {
    let Parser(tokens, pos, _) = parser

    Parser(tokens, pos, value) |> Ok()
  }
}

pub fn eof() -> fn(Parser(a)) -> Result(Parser(a), ParserFailure(b)) {
  fn(parser) {
    let Parser(tokens, pos, _) = parser

    case tokens {
      [token, ..] -> UnexpectedToken(Eof, token, pos) |> Error()
      [] -> Ok(parser)
    }
  }
}

const digit_pattern = "^[0-9]$"

const digit_or_decimal_point_pattern = "^[0-9.]$"

const whitespace_pattern = "^\\s$"

fn do_string(
  prev: Result(Parser(String), ParserFailure(a)),
  expected_tokens: List(String),
) -> Result(Parser(String), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parser) ->
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
              |> do_string(expected_rest)
          }
      }
  }
}

fn do_many(
  prev: Result(Parser(a), ParserFailure(b)),
  initial_value: c,
  combinator: fn(Parser(c)) -> Result(Parser(c), ParserFailure(b)),
  acc: fn(a, c) -> a,
) -> Result(Parser(a), ParserFailure(b)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parser) ->
      case Parser(parser.tokens, parser.pos, initial_value) |> combinator() {
        Error(_) -> prev
        Ok(many_parser) ->
          Parser(
            many_parser.tokens,
            many_parser.pos,
            acc(parser.value, many_parser.value),
          )
          |> Ok()
          |> do_many(initial_value, combinator, acc)
      }
  }
}

fn do_integer(
  prev: Result(Parser(String), ParserFailure(a)),
) -> Result(Parser(String), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parser) ->
      case parser.tokens {
        [] -> prev
        [token, ..rest] ->
          case is_digit(token) {
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
}

fn do_float(
  prev: Result(Parser(String), ParserFailure(a)),
  after_fraction: Bool,
) -> Result(Parser(String), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parser) ->
      case parser.tokens {
        [] -> prev
        [".", ..] if after_fraction -> prev
        [token, ..rest] ->
          case is_digit_or_decimal_point(token) {
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
}

fn do_until(
  prev: Result(Parser(String), ParserFailure(a)),
  terminator: String,
  expected_tokens: List(String),
) -> Result(Parser(String), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parser) ->
      case expected_tokens {
        [] -> prev
        [expected_token, ..] ->
          case parser.tokens {
            [] -> UnexpectedEof(Literal(terminator), parser.pos) |> Error()
            [actual_token, ..actual_rest] if actual_token == expected_token ->
              case
                parser.tokens
                |> string.join("")
                |> string.starts_with(terminator)
              {
                True -> prev
                False ->
                  Parser(
                    actual_rest,
                    increment_parser_position(parser.pos, actual_token),
                    parser.value <> actual_token,
                  )
                  |> Ok()
                  |> do_until(terminator, expected_tokens)
              }
            [actual_token, ..actual_rest] ->
              Parser(
                actual_rest,
                increment_parser_position(parser.pos, actual_token),
                parser.value <> actual_token,
              )
              |> Ok()
              |> do_until(terminator, expected_tokens)
          }
      }
  }
}

fn do_skip_until(
  prev: Result(Parser(a), ParserFailure(b)),
  terminator: String,
  expected_tokens: List(String),
) -> Result(Parser(a), ParserFailure(b)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parser) ->
      case expected_tokens {
        [] -> prev
        [expected_token, ..] ->
          case parser.tokens {
            [] -> UnexpectedEof(Literal(terminator), parser.pos) |> Error()
            [actual_token, ..actual_rest] if actual_token == expected_token ->
              case
                parser.tokens
                |> string.join("")
                |> string.starts_with(terminator)
              {
                True -> prev
                False ->
                  Parser(
                    actual_rest,
                    increment_parser_position(parser.pos, actual_token),
                    parser.value,
                  )
                  |> Ok()
                  |> do_skip_until(terminator, expected_tokens)
              }
            [actual_token, ..actual_rest] ->
              Parser(
                actual_rest,
                increment_parser_position(parser.pos, actual_token),
                parser.value,
              )
              |> Ok()
              |> do_skip_until(terminator, expected_tokens)
          }
      }
  }
}

fn do_whitespace(
  prev: Result(Parser(String), ParserFailure(a)),
) -> Result(Parser(String), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parser) ->
      case parser.tokens {
        [] -> prev
        [token, ..rest] ->
          case is_whitespace(token) {
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
}

fn do_one_of(
  prev: Result(Parser(a), ParserFailure(b)),
  entrypoint_parser: Parser(a),
  combinators: List(fn(Parser(a)) -> Result(Parser(a), ParserFailure(b))),
) -> Result(Parser(a), ParserFailure(b)) {
  case combinators {
    [] -> prev
    [combinator, ..rest] ->
      case entrypoint_parser |> combinator() {
        Ok(parser) -> Ok(parser)
        result -> do_one_of(result, entrypoint_parser, rest)
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

fn parse_string_as_integer(
  prev: Result(Parser(String), ParserFailure(a)),
  entrypoint_parser: Parser(b),
  mapper: fn(b, Int) -> b,
) -> Result(Parser(b), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(integer_parser) ->
      case int.parse(integer_parser.value) {
        Error(_) ->
          UnexpectedToken(
            Pattern(digit_pattern),
            integer_parser.value,
            integer_parser.pos,
          )
          |> Error()
        Ok(integer) ->
          Parser(
            integer_parser.tokens,
            integer_parser.pos,
            mapper(entrypoint_parser.value, integer),
          )
          |> Ok()
      }
  }
}

fn parse_string_as_float(
  prev: Result(Parser(String), ParserFailure(a)),
  entrypoint_parser: Parser(b),
  mapper: fn(b, Float) -> b,
) -> Result(Parser(b), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(float_parser) ->
      case
        float_parser.value
        |> add_integral_part_to_string_float_value()
        |> float.parse()
      {
        Error(_) ->
          UnexpectedToken(
            Pattern(digit_pattern),
            float_parser.value,
            float_parser.pos,
          )
          |> Error()
        Ok(float) ->
          Parser(
            float_parser.tokens,
            float_parser.pos,
            mapper(entrypoint_parser.value, float),
          )
          |> Ok()
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

fn matches_pattern(token: String, pattern: String) -> Bool {
  case regex.from_string(pattern) {
    Error(_) -> False
    Ok(pattern) -> regex.check(pattern, token)
  }
}

fn is_digit(token: String) -> Bool {
  matches_pattern(token, digit_pattern)
}

fn is_digit_or_decimal_point(token: String) -> Bool {
  matches_pattern(token, digit_or_decimal_point_pattern)
}

fn is_whitespace(token: String) -> Bool {
  matches_pattern(token, whitespace_pattern)
}
