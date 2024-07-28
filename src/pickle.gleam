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
  Eol
  Eof
  NonEof
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
  Until1Error(pos: ParserPosition)
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

/// Applies the initial value to the given parser.
/// 
/// This parser is especially useful when you want or need to transform a
/// value of a different type than the one the parent parser holds
/// (e.g., a type that the AST type of the parent parser can contain).
pub fn do(
  initial_value: a,
  parser: Parser(a, b, c),
  mapper: fn(d, b) -> d,
) -> Parser(d, d, c) {
  fn(parsed) {
    let Parsed(tokens, pos, value) = parsed

    case Parsed(tokens, pos, initial_value) |> parser() {
      Error(failure) -> Error(failure)
      Ok(do_parsed) ->
        Parsed(do_parsed.tokens, do_parsed.pos, mapper(value, do_parsed.value))
        |> Ok()
    }
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
      Ok(string_parsed) ->
        Parsed(
          string_parsed.tokens,
          string_parsed.pos,
          mapper(value, string_parsed.value),
        )
        |> Ok()
    }
  }
}

/// Parses a single token of any kind and fails if there is no further input
/// left to parse.
pub fn any(mapper: fn(a, String) -> a) -> Parser(a, a, b) {
  take_if(fn(_) { True }, NonEof, mapper)
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
/// times until it fails.
pub fn many(
  initial_value: a,
  parser: Parser(a, b, c),
  acc: fn(d, b) -> d,
) -> Parser(d, d, c) {
  fn(parsed) {
    Ok(parsed)
    |> do_many(initial_value, parser, acc, None)
  }
}

/// Applies the initial value to the given parser one to `n`
/// times until it fails.
/// 
/// The given parser must succeed at least once.
pub fn many1(
  initial_value: a,
  parser: Parser(a, b, c),
  acc: fn(d, b) -> d,
) -> Parser(d, d, c) {
  fn(parsed) {
    Ok(parsed)
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

/// Applies the given parser zero to `n` times until the given terminator
/// succeeds.
/// 
/// It fails if the given parser fails or the given terminator doesn't
/// succeed before no further tokens are left to parse.
pub fn until(
  initial_value: a,
  parser: Parser(a, a, c),
  terminator: Parser(d, b, c),
  acc: fn(d, a) -> d,
) -> Parser(d, d, c) {
  fn(parsed) {
    Ok(parsed) |> do_until(initial_value, parser, terminator, acc, None)
  }
}

/// Applies the given parser one to `n` times until the given terminator
/// succeeds.
/// 
/// It fails if the given parser fails or could not be applied once, or the given
/// terminator doesn't succeed before no further tokens are left to parse.
/// 
/// If the terminator succeeds before the given parser could succeed, an
/// `Until1Error` with the current parser position will be returned.
pub fn until1(
  initial_value: a,
  parser: Parser(a, a, c),
  terminator: Parser(d, b, c),
  acc: fn(d, a) -> d,
) -> Parser(d, d, c) {
  fn(parsed) {
    Ok(parsed) |> do_until(initial_value, parser, terminator, acc, Some(1))
  }
}

/// Applies the given parser zero to `n` times until the given terminator
/// succeeds and drops the parsed tokens.
/// 
/// It fails if the given terminator doesn't succeed before no further
/// tokens are left to parse.
pub fn skip_until(terminator: Parser(a, b, c)) -> Parser(a, a, c) {
  until("", any(drop), terminator, drop)
}

/// Applies the given parser one to `n` times until the given terminator
/// succeeds and drops the parsed tokens.
/// 
/// It fails if no single token could be skipped or the given terminator
/// doesn't succeed before no further tokens are left to parse.
/// 
/// If the terminator succeeds before no single token could be skipped,
/// an `Until1Error` with the current parser position will be returned.
pub fn skip_until1(terminator: Parser(a, b, c)) -> Parser(a, a, c) {
  until1("", any(drop), terminator, drop)
}

/// Parses whitespace zero to `n` times until encountering a non-whitespace
/// token.
pub fn whitespace(mapper: fn(a, String) -> a) -> Parser(a, a, b) {
  many("", take_if(is_whitespace, Whitespace, apppend_to_string), mapper)
}

/// Parses whitespace one to `n` times until encountering a non-whitespace
/// token.
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
  fn(parsed) { Ok(parsed) |> do_one_of(parsed, parsers, []) }
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

/// Parses an end-of-line character.
pub fn eol(mapper: fn(a, String) -> a) -> Parser(a, a, b) {
  take_if(is_eol, Eol, mapper)
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

/// Looksahead whether the given parser succeeds and backtracks if
/// it does.
pub fn lookahead(parser: Parser(a, b, c)) -> Parser(a, a, c) {
  fn(parsed) { do_lookahead(parsed, parsed, parser) }
}

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
  parser: Parser(c, d, b),
  acc: fn(a, d) -> a,
  attempt: Option(Int),
) -> Result(Parsed(a), ParserFailure(b)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parsed) ->
      case parsed |> do(initial_value, parser, acc) {
        Error(failure) ->
          case attempt {
            Some(1) -> Error(failure)
            None | Some(_) -> prev
          }
        many_parsed ->
          do_many(
            many_parsed,
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
  prev: Result(Parsed(d), ParserFailure(c)),
  initial_value: a,
  parser: Parser(a, a, c),
  terminator: Parser(d, b, c),
  acc: fn(d, a) -> d,
  attempt: Option(Int),
) -> Result(Parsed(d), ParserFailure(c)) {
  case prev {
    Error(failure) -> Error(failure)
    Ok(parsed) ->
      case terminator(parsed) {
        Ok(_) ->
          case attempt {
            Some(1) -> Until1Error(parsed.pos) |> Error()
            None | Some(_) ->
              Parsed(
                parsed.tokens,
                parsed.pos,
                acc(parsed.value, initial_value),
              )
              |> Ok()
          }
        Error(failure) ->
          case parsed.tokens {
            [] -> Error(failure)
            _ ->
              case
                Parsed(parsed.tokens, parsed.pos, initial_value) |> parser()
              {
                Error(failure) -> Error(failure)
                Ok(until_parsed) ->
                  Parsed(until_parsed.tokens, until_parsed.pos, parsed.value)
                  |> Ok()
                  |> do_until(
                    until_parsed.value,
                    parser,
                    terminator,
                    acc,
                    option.map(attempt, fn(i) { i + 1 }),
                  )
              }
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

fn do_lookahead(
  prev_parsed: Parsed(a),
  entrypoint_parsed: Parsed(a),
  parser: Parser(a, b, c),
) -> Result(Parsed(a), ParserFailure(c)) {
  let Parsed(tokens, pos, value) = prev_parsed

  case parser(prev_parsed) {
    Ok(_) -> Ok(entrypoint_parsed)
    Error(failure) ->
      case tokens {
        [] -> Error(failure)
        [token, ..rest] ->
          Parsed(rest, increment_parser_position(pos, token), value)
          |> do_lookahead(entrypoint_parsed, parser)
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
  case regex.from_string("^" <> pattern <> "$") {
    Error(_) -> False
    Ok(pattern) -> regex.check(pattern, token)
  }
}

fn is_binary_digit(token: String) -> Bool {
  matches_pattern(token, "[01]")
}

fn is_decimal_digit(token: String) -> Bool {
  matches_pattern(token, "[0-9]")
}

fn is_hexadecimal_digit(token: String) -> Bool {
  matches_pattern(token, "[0-9a-fA-F]")
}

fn is_octal_digit(token: String) -> Bool {
  matches_pattern(token, "[0-7]")
}

fn is_decimal_digit_or_point(token: String) -> Bool {
  matches_pattern(token, "[0-9.]")
}

fn is_whitespace(token: String) -> Bool {
  matches_pattern(token, "\\s")
}

fn is_eol(token: String) -> Bool {
  matches_pattern(token, "\n|\r\n")
}

fn is_ascii_letter(token: String) -> Bool {
  matches_pattern(token, "[a-zA-Z]")
}

fn is_lowercase_ascii_letter(token: String) -> Bool {
  matches_pattern(token, "[a-z]")
}

fn is_uppercase_ascii_letter(token: String) -> Bool {
  matches_pattern(token, "[A-Z]")
}
