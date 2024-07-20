import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/regex
import gleam/string

/// The type to represent the current position of the parser.
pub type ParserPosition {
  ParserPosition(row: Int, col: Int)
}

/// The type to store unconsumed tokens, the position of the
/// parser and the current value.
pub opaque type Parsed(a) {
  Parsed(tokens: List(String), pos: ParserPosition, value: a)
}

/// The parser type that is an alias for a function that is
/// responsible for parsing input.
pub type Parser(a, b, c) =
  fn(Parsed(a)) -> Result(Parsed(b), ParserFailure(c))

/// The type to represent a kind of token that was expected at a
/// specific position of the input that couldn't be found.
pub type ExpectedToken {
  Eof
  Float
  Integer
  OctalDigit
  BinaryDigit
  DecimalDigit
  HexadecimalDigit
  DecimalDigitOrPoint
  AsciiLetter
  LowercaseAsciiLetter
  UppercaseAsciiLetter
  Whitespace
  String(String)
}

/// The error type to represent a reason why a parser failed to
/// parse the input.
pub type ParserFailure(a) {
  UnexpectedToken(
    expected_token: ExpectedToken,
    actual_token: String,
    pos: ParserPosition,
  )
  UnexpectedEof(expected_token: ExpectedToken, pos: ParserPosition)
  OneOfError(failures: List(ParserFailure(a)))
  GuardError(error: a, pos: ParserPosition)
  NotError(error: a, pos: ParserPosition)
  CustomError(error: a)
}

/// A mapper to drop the parsed value of the child parser, thus
/// leaving the value of the parent parser unchanged.
pub fn drop(value: a, _: b) -> a {
  value
}

/// A mapper to append the parsed string of the child parser to
/// the string value of the parent parser.
pub fn apppend_to_string(value: String, appendage: String) -> String {
  value <> appendage
}

/// A mapper to prepend the parsed value of the child parser to
/// the list value of the parent parser.
pub fn prepend_to_list(value: List(a), appendage: a) -> List(a) {
  [appendage, ..value]
}

/// Applies the provided input and initial value to the given parser
/// to parse the input and transform the initial value.
pub fn parse(
  input: String,
  initial_value: a,
  parser: Parser(a, b, c),
) -> Result(b, ParserFailure(c)) {
  case
    Parsed(string.to_graphemes(input), ParserPosition(0, 0), initial_value)
    |> parser()
  {
    Error(failure) -> Error(failure)
    Ok(parser) -> Ok(parser.value)
  }
}

/// Chains two given parsers.
/// 
/// If `prev` fails, `successor` won't be invoked.
pub fn then(
  prev: Parser(a, b, c),
  successor: Parser(b, d, c),
) -> Parser(a, d, c) {
  fn(parsed) {
    case prev(parsed) {
      Error(failure) -> Error(failure)
      Ok(next_parsed) -> successor(next_parsed)
    }
  }
}

/// Validates the value of the parser.
/// 
/// If the validation fails, a `GuardError` with the given `error`
/// will be returned.
pub fn guard(predicate: fn(a) -> Bool, error: b) -> Parser(a, a, b) {
  fn(parsed) {
    let Parsed(_, pos, value) = parsed

    case predicate(value) {
      False -> GuardError(error, pos) |> Error()
      True -> Ok(parsed)
    }
  }
}

/// Maps the value of the parser.
pub fn map(mapper: fn(a) -> b) -> Parser(a, b, c) {
  fn(parsed) {
    let Parsed(tokens, pos, value) = parsed

    Parsed(tokens, pos, mapper(value)) |> Ok()
  }
}

/// Maps the error returned by the parser.
pub fn map_error(
  parser: Parser(a, a, b),
  mapper: fn(ParserFailure(b)) -> b,
) -> Parser(a, a, b) {
  fn(parsed) {
    case parser(parsed) {
      Error(failure) -> mapper(failure) |> CustomError() |> Error()
      result -> result
    }
  }
}

/// Parses a specific string.
pub fn string(expected: String, mapper: fn(a, String) -> a) -> Parser(a, a, b) {
  fn(parsed) {
    let Parsed(tokens, pos, value) = parsed

    case
      Parsed(tokens, pos, "")
      |> Ok()
      |> do_string(string.to_graphemes(expected))
    {
      Error(failure) -> Error(failure)
      Ok(token_parsed) ->
        Parsed(
          token_parsed.tokens,
          token_parsed.pos,
          mapper(value, token_parsed.value),
        )
        |> Ok()
    }
  }
}

/// Parses an ASCII letter.
pub fn ascii_letter(mapper: fn(a, String) -> a) -> Parser(a, a, b) {
  take_if(is_ascii_letter, AsciiLetter, mapper)
}

/// Parses a lowercase ASCII letter.
pub fn lowercase_ascii_letter(mapper: fn(a, String) -> a) -> Parser(a, a, b) {
  take_if(is_lowercase_ascii_letter, LowercaseAsciiLetter, mapper)
}

/// Parses an uppercase ASCII letter.
pub fn uppercase_ascii_letter(mapper: fn(a, String) -> a) -> Parser(a, a, b) {
  take_if(is_uppercase_ascii_letter, UppercaseAsciiLetter, mapper)
}

/// Applies the given parser, and if it fails, ignores its failure and
/// backtracks.
pub fn optional(parser: Parser(a, a, b)) -> Parser(a, a, b) {
  fn(parsed) {
    case parser(parsed) {
      Error(_) -> Ok(parsed)
      result -> result
    }
  }
}

/// Applies the initial value to the given parser zero to `n`
/// times until it fails. The `acc` callback decides how to
/// apply the parsed value to the value of the parent parser.
pub fn many(
  initial_value: a,
  parser: Parser(a, a, b),
  acc: fn(c, a) -> c,
) -> Parser(c, c, b) {
  fn(parsed) {
    parsed
    |> Ok()
    |> do_many(initial_value, parser, acc, None)
  }
}

/// Applies the initial value to the given parser one to `n`
/// times until it fails. The `acc` callback decides how to
/// apply the parsed value to the value of the parent parser.
/// 
/// The given parser must succeed at least once.
pub fn many1(
  initial_value: a,
  parser: Parser(a, a, b),
  acc: fn(c, a) -> c,
) -> Parser(c, c, b) {
  fn(parsed) {
    parsed
    |> Ok()
    |> do_many(initial_value, parser, acc, Some(1))
  }
}

/// Parses a binary integer.
pub fn binary_integer(mapper: fn(a, Int) -> a) -> Parser(a, a, b) {
  do_integer("b", "B", 2, BinaryDigit, is_binary_digit, mapper)
}

/// Parses a decimal integer.
pub fn decimal_integer(mapper: fn(a, Int) -> a) -> Parser(a, a, b) {
  do_integer("d", "D", 10, DecimalDigit, is_decimal_digit, mapper)
}

/// Parses a hexadecimal integer.
pub fn hexadecimal_integer(mapper: fn(a, Int) -> a) -> Parser(a, a, b) {
  do_integer("x", "X", 16, HexadecimalDigit, is_hexadecimal_digit, mapper)
}

/// Parses an octal integer.
pub fn octal_integer(mapper: fn(a, Int) -> a) -> Parser(a, a, b) {
  do_integer("o", "O", 8, OctalDigit, is_octal_digit, mapper)
}

/// Parses an integer of different numeric formats (binary, decimal, hexadecimal
/// and octal).
pub fn integer(mapper: fn(a, Int) -> a) -> Parser(a, a, b) {
  fn(parsed) {
    let Parsed(tokens, _, _) = parsed

    case tokens {
      ["0", "b", ..] | ["0", "B", ..] -> parsed |> binary_integer(mapper)
      ["0", "d", ..] | ["0", "D", ..] -> parsed |> decimal_integer(mapper)
      ["0", "x", ..] | ["0", "X", ..] -> parsed |> hexadecimal_integer(mapper)
      ["0", "o", ..] | ["0", "O", ..] -> parsed |> octal_integer(mapper)
      _ ->
        parsed
        |> one_of([
          decimal_integer(mapper),
          binary_integer(mapper),
          hexadecimal_integer(mapper),
          octal_integer(mapper),
        ])
    }
  }
}

/// Parses a decimal float.
/// 
/// This function will be adjusted to support different numeric
/// formats in later versions.
pub fn float(mapper: fn(a, Float) -> a) -> Parser(a, a, b) {
  fn(parsed) {
    let Parsed(tokens, pos, _) = parsed

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
        Parsed(rest, increment_parser_position(pos, token), token)
        |> Ok()
        |> do_float(False)
        |> parse_string_as_float(parsed, mapper)
      [token, ..rest] if token == "+" || token == "-" ->
        case rest {
          [] ->
            UnexpectedEof(
              DecimalDigitOrPoint,
              increment_parser_position(pos, token),
            )
            |> Error()
          tokens ->
            Parsed(tokens, increment_parser_position(pos, token), token)
            |> Ok()
            |> do_float(False)
            |> parse_string_as_float(parsed, mapper)
        }
      [token, ..] ->
        UnexpectedToken(DecimalDigitOrPoint, token, pos)
        |> Error()
      [] ->
        UnexpectedEof(DecimalDigitOrPoint, pos)
        |> Error()
    }
  }
}

/// Applies the given parser zero to `n` times until it succeeds.
/// The mapper decides how to apply the parsed string to the value
/// of the parent parser.
pub fn until(
  terminator: Parser(String, String, b),
  mapper: fn(a, String) -> a,
) -> Parser(a, a, b) {
  fn(parsed) {
    let Parsed(tokens, pos, value) = parsed

    case
      Parsed(tokens, pos, "")
      |> Ok()
      |> do_until(terminator)
    {
      Error(failure) -> Error(failure)
      Ok(until_parsed) ->
        Parsed(
          until_parsed.tokens,
          until_parsed.pos,
          mapper(value, until_parsed.value),
        )
        |> Ok()
    }
  }
}

/// Applies the given parser zero to `n` times until it succeeds and
/// drops the parsed tokens.
pub fn skip_until(terminator: Parser(String, String, b)) -> Parser(a, a, b) {
  until(terminator, drop)
}

/// Parses whitespace zero to `n` times until encountering a non-whitespace
/// token. The mapper decides how to apply the parsed whitespace to the
/// value of the parent parser.
pub fn whitespace(mapper: fn(a, String) -> a) -> Parser(a, a, b) {
  many("", take_if(is_whitespace, Whitespace, apppend_to_string), mapper)
}

/// Parses whitespace one to `n` times until encountering a non-whitespace
/// token. The mapper decides how to apply the parsed whitespace to the
/// value of the parent parser.
/// 
/// It fails if not at least one whitespace token could be parsed.
pub fn whitespace1(mapper: fn(a, String) -> a) -> Parser(a, a, b) {
  many1("", take_if(is_whitespace, Whitespace, apppend_to_string), mapper)
}

/// Parses whitespace zero to `n` times until encountering a non-whitespace
/// token and drops the parsed whitespace.
pub fn skip_whitespace() -> Parser(a, a, b) {
  whitespace(drop)
}

/// Parses whitespace one to `n` times until encountering a non-whitespace
/// token and drops the parsed whitespace.
/// 
/// It fails if not at least one whitespace token could be parsed.
pub fn skip_whitespace1() -> Parser(a, a, b) {
  whitespace1(drop)
}

/// Applies each given parser in order until one succeeds. If all parsers
/// failed, the collected failures wrapped in an `OneOfError` will be
/// returned.
pub fn one_of(parsers: List(Parser(a, a, b))) -> Parser(a, a, b) {
  fn(parsed) { parsed |> Ok() |> do_one_of(parsed, parsers, []) }
}

/// Replaces the value of the parser with the given value.
pub fn return(value: a) -> Parser(b, a, c) {
  fn(parsed) {
    let Parsed(tokens, pos, _) = parsed

    Parsed(tokens, pos, value) |> Ok()
  }
}

/// Parses successfully when there is no further input left to parse. 
pub fn eof() -> Parser(a, a, b) {
  fn(parsed) {
    let Parsed(tokens, pos, _) = parsed

    case tokens {
      [token, ..] -> UnexpectedToken(Eof, token, pos) |> Error()
      [] -> Ok(parsed)
    }
  }
}

/// Succeeds and backtracks if the given parser fails.
/// 
/// The `error` parameter is meant to convey more information
/// to consumers and its value is wrapped in a `NotError`.
pub fn not(parser: Parser(a, b, c), error: c) -> Parser(a, a, c) {
  fn(parsed) {
    let Parsed(_, pos, _) = parsed

    case parser(parsed) {
      Error(_) -> Ok(parsed)
      Ok(_) -> NotError(error, pos) |> Error()
    }
  }
}

const binary_digit_pattern = "^[01]$"

const decimal_digit_pattern = "^[0-9]$"

const hexadecimal_digit_pattern = "^[0-9a-fA-F]$"

const octal_digit_pattern = "^[0-7]$"

const decimal_digit_or_point_pattern = "^[0-9.]$"

const whitespace_pattern = "^\\s$"

const ascii_letter_pattern = "^[a-zA-Z]$"

const lowercase_ascii_letter_pattern = "^[a-z]$"

const uppercase_ascii_letter_pattern = "^[A-Z]$"

fn take_if(
  predicate: fn(String) -> Bool,
  expected_token: ExpectedToken,
  mapper: fn(a, String) -> a,
) -> Parser(a, a, b) {
  fn(parsed) {
    let Parsed(tokens, pos, value) = parsed

    case tokens {
      [] -> UnexpectedEof(expected_token, pos) |> Error()
      [token, ..rest] ->
        case predicate(token) {
          False -> UnexpectedToken(expected_token, token, pos) |> Error()
          True ->
            Parsed(
              rest,
              increment_parser_position(pos, token),
              mapper(value, token),
            )
            |> Ok()
        }
    }
  }
}

fn do_string(
  prev: Result(Parsed(String), ParserFailure(a)),
  expected_tokens: List(String),
) -> Result(Parsed(String), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parsed) ->
      case expected_tokens {
        [] -> prev
        [expected_token, ..expected_rest] ->
          case parsed.tokens {
            [] ->
              UnexpectedEof(
                String(parsed.value <> string.join(expected_tokens, "")),
                parsed.pos,
              )
              |> Error()
            [actual_token, ..] if expected_token != actual_token ->
              UnexpectedToken(
                String(parsed.value <> string.join(expected_tokens, "")),
                parsed.value <> actual_token,
                parsed.pos,
              )
              |> Error()
            [actual_token, ..actual_rest] ->
              Parsed(
                actual_rest,
                increment_parser_position(parsed.pos, actual_token),
                parsed.value <> actual_token,
              )
              |> Ok()
              |> do_string(expected_rest)
          }
      }
  }
}

fn do_many(
  prev: Result(Parsed(a), ParserFailure(b)),
  initial_value: c,
  parser: Parser(c, c, b),
  acc: fn(a, c) -> a,
  attempt: Option(Int),
) -> Result(Parsed(a), ParserFailure(b)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parsed) ->
      case Parsed(parsed.tokens, parsed.pos, initial_value) |> parser() {
        Error(failure) ->
          case attempt {
            Some(1) -> Error(failure)
            None | Some(_) -> prev
          }
        Ok(many_parsed) ->
          Parsed(
            many_parsed.tokens,
            many_parsed.pos,
            acc(parsed.value, many_parsed.value),
          )
          |> Ok()
          |> do_many(
            initial_value,
            parser,
            acc,
            option.map(attempt, fn(i) { i + 1 }),
          )
      }
  }
}

fn do_integer(
  format_prefix_lowercase: String,
  format_prefix_uppercase: String,
  base: Int,
  expected_token: ExpectedToken,
  digit_predicate: fn(String) -> Bool,
  mapper: fn(a, Int) -> a,
) -> Parser(a, a, b) {
  fn(parsed) {
    let Parsed(tokens, pos, _) = parsed

    case tokens {
      [] -> UnexpectedEof(expected_token, pos) |> Error()
      ["0", token, ..rest] ->
        case
          token == format_prefix_lowercase || token == format_prefix_uppercase
        {
          False ->
            Parsed([token, ..rest], increment_parser_position(pos, "0"), "0")
            |> Ok()
            |> collect_integer_digits(digit_predicate)
            |> parse_string_as_integer(parsed, base, mapper)

          True ->
            case rest {
              [] ->
                UnexpectedEof(
                  expected_token,
                  increment_parser_position(pos, "0" <> token),
                )
                |> Error()
              [digit, ..rest] ->
                case digit_predicate(digit) {
                  False ->
                    UnexpectedToken(
                      expected_token,
                      digit,
                      increment_parser_position(pos, "0" <> token),
                    )
                    |> Error()
                  True ->
                    Parsed(
                      rest,
                      increment_parser_position(pos, "0" <> token <> digit),
                      digit,
                    )
                    |> Ok()
                    |> collect_integer_digits(digit_predicate)
                    |> parse_string_as_integer(parsed, base, mapper)
                }
            }
        }
      [sign, ..rest] if sign == "+" || sign == "-" ->
        case rest {
          [] ->
            UnexpectedEof(expected_token, increment_parser_position(pos, sign))
            |> Error()
          [token, ..rest] ->
            case digit_predicate(token) {
              False ->
                UnexpectedToken(
                  expected_token,
                  token,
                  increment_parser_position(pos, sign),
                )
                |> Error()
              True ->
                Parsed(
                  rest,
                  increment_parser_position(pos, sign <> token),
                  sign <> token,
                )
                |> Ok()
                |> collect_integer_digits(digit_predicate)
                |> parse_string_as_integer(parsed, base, mapper)
            }
        }
      [token, ..rest] ->
        case digit_predicate(token) {
          False -> UnexpectedToken(expected_token, token, pos) |> Error()
          True ->
            Parsed(rest, increment_parser_position(pos, token), token)
            |> Ok()
            |> collect_integer_digits(digit_predicate)
            |> parse_string_as_integer(parsed, base, mapper)
        }
    }
  }
}

fn do_float(
  prev: Result(Parsed(String), ParserFailure(a)),
  after_fraction: Bool,
) -> Result(Parsed(String), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parsed) ->
      case parsed.tokens {
        [] -> prev
        [".", ..] if after_fraction -> prev
        [token, ..rest] ->
          case is_decimal_digit_or_point(token) {
            False -> prev
            True ->
              Parsed(
                rest,
                increment_parser_position(parsed.pos, token),
                parsed.value <> token,
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
  prev: Result(Parsed(String), ParserFailure(a)),
  terminator: Parser(String, String, a),
) -> Result(Parsed(String), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parsed) -> {
      case terminator(parsed) {
        Error(failure) ->
          case parsed.tokens {
            [] -> Error(failure)
            [token, ..rest] ->
              Parsed(
                rest,
                increment_parser_position(parsed.pos, token),
                parsed.value <> token,
              )
              |> Ok()
              |> do_until(terminator)
          }
        Ok(_) -> Parsed(parsed.tokens, parsed.pos, parsed.value) |> Ok()
      }
    }
  }
}

fn do_one_of(
  prev: Result(Parsed(a), ParserFailure(b)),
  entrypoint_parsed: Parsed(a),
  parsers: List(Parser(a, a, b)),
  failures: List(ParserFailure(b)),
) -> Result(Parsed(a), ParserFailure(b)) {
  case parsers {
    [] ->
      case failures {
        [] -> prev
        _ -> OneOfError(failures) |> Error()
      }
    [parser, ..rest] ->
      case entrypoint_parsed |> parser() {
        Error(failure) ->
          Error(failure)
          |> do_one_of(entrypoint_parsed, rest, [failure, ..failures])
        result -> result
      }
  }
}

fn collect_integer_digits(
  prev: Result(Parsed(String), ParserFailure(a)),
  digit_predicate: fn(String) -> Bool,
) -> Result(Parsed(String), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parsed) ->
      case parsed.tokens {
        [] -> prev
        [token, ..rest] ->
          case digit_predicate(token) {
            False -> prev
            True ->
              Parsed(
                rest,
                increment_parser_position(parsed.pos, token),
                parsed.value <> token,
              )
              |> Ok()
              |> collect_integer_digits(digit_predicate)
          }
      }
  }
}

fn remove_leading_plus_sign_from_string(value: String) -> String {
  case value {
    "+" <> rest -> rest
    _ -> value
  }
}

fn add_integral_part_to_string_float_value(float_as_string: String) -> String {
  case float_as_string {
    "." <> rest -> "0." <> rest
    "-" <> rest ->
      case rest {
        "." <> fraction -> "-0." <> fraction
        float -> "-" <> float
      }
    float -> float
  }
}

fn parse_string_as_integer(
  prev: Result(Parsed(String), ParserFailure(a)),
  entrypoint_parsed: Parsed(b),
  base: Int,
  mapper: fn(b, Int) -> b,
) -> Result(Parsed(b), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(integer_parsed) ->
      case
        remove_leading_plus_sign_from_string(integer_parsed.value)
        |> int.base_parse(base)
      {
        Error(_) ->
          UnexpectedToken(Integer, integer_parsed.value, integer_parsed.pos)
          |> Error()
        Ok(integer) ->
          Parsed(
            integer_parsed.tokens,
            integer_parsed.pos,
            mapper(entrypoint_parsed.value, integer),
          )
          |> Ok()
      }
  }
}

fn parse_string_as_float(
  prev: Result(Parsed(String), ParserFailure(a)),
  entrypoint_parsed: Parsed(b),
  mapper: fn(b, Float) -> b,
) -> Result(Parsed(b), ParserFailure(a)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(float_parsed) ->
      case
        float_parsed.value
        |> add_integral_part_to_string_float_value()
        |> float.parse()
      {
        Error(_) ->
          UnexpectedToken(Float, float_parsed.value, float_parsed.pos)
          |> Error()
        Ok(float) ->
          Parsed(
            float_parsed.tokens,
            float_parsed.pos,
            mapper(entrypoint_parsed.value, float),
          )
          |> Ok()
      }
  }
}

fn increment_parser_position(
  prev: ParserPosition,
  tokens: String,
) -> ParserPosition {
  case string.to_graphemes(tokens) {
    [] -> prev
    [token, ..rest] if token == "\n" || token == "\r\n" ->
      ParserPosition(prev.row + 1, 0)
      |> increment_parser_position(string.join(rest, ""))
    [_, ..rest] ->
      ParserPosition(prev.row, prev.col + 1)
      |> increment_parser_position(string.join(rest, ""))
  }
}

fn matches_pattern(token: String, pattern: String) -> Bool {
  case regex.from_string(pattern) {
    Error(_) -> False
    Ok(pattern) -> regex.check(pattern, token)
  }
}

fn is_binary_digit(token: String) -> Bool {
  matches_pattern(token, binary_digit_pattern)
}

fn is_decimal_digit(token: String) -> Bool {
  matches_pattern(token, decimal_digit_pattern)
}

fn is_hexadecimal_digit(token: String) -> Bool {
  matches_pattern(token, hexadecimal_digit_pattern)
}

fn is_octal_digit(token: String) -> Bool {
  matches_pattern(token, octal_digit_pattern)
}

fn is_decimal_digit_or_point(token: String) -> Bool {
  matches_pattern(token, decimal_digit_or_point_pattern)
}

fn is_whitespace(token: String) -> Bool {
  matches_pattern(token, whitespace_pattern)
}

fn is_ascii_letter(token: String) -> Bool {
  matches_pattern(token, ascii_letter_pattern)
}

fn is_lowercase_ascii_letter(token: String) -> Bool {
  matches_pattern(token, lowercase_ascii_letter_pattern)
}

fn is_uppercase_ascii_letter(token: String) -> Bool {
  matches_pattern(token, uppercase_ascii_letter_pattern)
}
