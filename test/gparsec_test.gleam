import gleam/string
import gparsec.{
  type Parser, type ParserMapperCallback, type ParserResult, Literal, Parser,
  ParserPosition, Pattern, UnexpectedEof, UnexpectedToken,
}
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn parse_tests() {
  describe("gparsec/parse", [
    it(
      "returns the parser value when the provided parser callback succeeded",
      fn() {
        gparsec.parse("abc", "", fn(result) { result })
        |> expect.to_be_ok()
        |> expect.to_equal("")
      },
    ),
    it("returns an error when the provided parser callback failed", fn() {
      gparsec.parse("abc", "", fn(_) {
        UnexpectedEof(Literal("a"), ParserPosition(0, 0)) |> Error()
      })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Literal("a"), ParserPosition(0, 0)))
    }),
  ])
}

pub fn token_tests() {
  describe("gparsec/token", [
    it("returns a parser that parsed a single token", fn() {
      new_parser("abc", "Characters: ")
      |> gparsec.token("a", fn(value, token) { value <> token })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser(
        ["b", "c"],
        ParserPosition(0, 1),
        "Characters: a",
      ))
    }),
    it("returns a parser that parsed a set of tokens", fn() {
      new_parser("abcdefg", "Characters: ")
      |> gparsec.token("abc", fn(value, tokens) { value <> tokens })
      |> gparsec.token("def", fn(value, tokens) { value <> tokens })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser(
        ["g"],
        ParserPosition(0, 6),
        "Characters: abcdef",
      ))
    }),
    it("returns a parser with a position that detected line breaks", fn() {
      new_parser("abc\ndef", "Characters: ")
      |> gparsec.token("abc", fn(value, tokens) { value <> tokens })
      |> gparsec.token("\n", gparsec.ignore_token)
      |> gparsec.token("def", fn(value, tokens) { value <> tokens })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(1, 3), "Characters: abcdef"))
    }),
    it("returns an error when encountering an unexpected token", fn() {
      new_parser("abcd", "")
      |> gparsec.token("abdz", fn(value, tokens) { value <> tokens })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("abdz"),
        "abc",
        ParserPosition(0, 2),
      ))
    }),
    it("returns an error when encountering an unexpected EOF", fn() {
      new_parser("abc", "")
      |> gparsec.token("abcd", fn(value, tokens) { value <> tokens })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Literal("abcd"), ParserPosition(0, 3)))
    }),
  ])
}

pub fn optional_tests() {
  describe("gparsec/optional", [
    it(
      "returns a parser that parsed a set of tokens including some optional tokens",
      fn() {
        new_parser("(a,b)", Pair("", ""))
        |> gparsec.optional(gparsec.token(_, "(", gparsec.ignore_token))
        |> gparsec.token("a", fn(value, token) { Pair(..value, left: token) })
        |> gparsec.token(",", gparsec.ignore_token)
        |> gparsec.token("b", fn(value, token) { Pair(..value, right: token) })
        |> gparsec.optional(gparsec.token(_, ")", gparsec.ignore_token))
        |> expect.to_be_ok()
        |> expect.to_equal(Parser([], ParserPosition(0, 5), Pair("a", "b")))
      },
    ),
    it(
      "returns a parser that parsed a set of tokens including some missing optional tokens",
      fn() {
        new_parser("a,b)", Pair("", ""))
        |> gparsec.optional(gparsec.token(_, "(", gparsec.ignore_token))
        |> gparsec.token("a", fn(value, token) { Pair(..value, left: token) })
        |> gparsec.token(",", gparsec.ignore_token)
        |> gparsec.token("b", fn(value, token) { Pair(..value, right: token) })
        |> gparsec.optional(gparsec.token(_, ")", gparsec.ignore_token))
        |> expect.to_be_ok()
        |> expect.to_equal(Parser([], ParserPosition(0, 4), Pair("a", "b")))
      },
    ),
    it("returns an error when a prior parser failed", fn() {
      new_parser("(a,b)", Pair("", ""))
      |> gparsec.token("what's going on here ...", gparsec.ignore_token)
      |> gparsec.optional(gparsec.token(_, "(", gparsec.ignore_token))
      |> gparsec.token("a", fn(value, token) { Pair(..value, left: token) })
      |> gparsec.token(",", gparsec.ignore_token)
      |> gparsec.token("b", fn(value, token) { Pair(..value, right: token) })
      |> gparsec.optional(gparsec.token(_, ")", gparsec.ignore_token))
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("what's going on here ..."),
        "(",
        ParserPosition(0, 0),
      ))
    }),
  ])
}

pub fn many_tests() {
  describe("gparsec/many", [
    it("returns a parser that parsed multiple tokens", fn() {
      new_parser("aaab", "Characters: ")
      |> gparsec.many(gparsec.token(_, "a", fn(value, token) { value <> token }))
      |> expect.to_be_ok()
      |> expect.to_equal(Parser(["b"], ParserPosition(0, 3), "Characters: aaa"))
    }),
    it("returns a parser that parsed no tokens", fn() {
      new_parser("abab", "Characters: ")
      |> gparsec.many(gparsec.token(
        _,
        "aa",
        fn(value, token) { value <> token },
      ))
      |> gparsec.token("ab", fn(value, token) { value <> token })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser(
        ["a", "b"],
        ParserPosition(0, 2),
        "Characters: ab",
      ))
    }),
    it("returns an error when a prior parser failed", fn() {
      new_parser("aaa", "Characters: ")
      |> gparsec.token("ab", fn(value, token) { value <> token })
      |> gparsec.many(gparsec.token(_, "a", fn(value, token) { value <> token }))
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("ab"),
        "aa",
        ParserPosition(0, 1),
      ))
    }),
  ])
}

pub fn integer_tests() {
  describe("gparsec/integer", [
    it("returns a parser that parsed a positive integer", fn() {
      new_parser("250", 0)
      |> gparsec.integer(fn(_, integer) { integer })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 3), 250))
    }),
    it(
      "returns a parser that parsed a positive integer with an explicit sign",
      fn() {
        new_parser("+120", 0)
        |> gparsec.integer(fn(_, integer) { integer })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser([], ParserPosition(0, 4), 120))
      },
    ),
    it("returns a parser that parsed a negative integer", fn() {
      new_parser("-75", 0)
      |> gparsec.integer(fn(_, integer) { integer })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 3), -75))
    }),
    it(
      "returns a parser that parsed an integer and ignored non-digit tokens afterwards",
      fn() {
        new_parser("5005abc", 0)
        |> gparsec.integer(fn(_, integer) { integer })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser(["a", "b", "c"], ParserPosition(0, 4), 5005))
      },
    ),
    it("returns a parser that parsed multiple integers", fn() {
      new_parser("[20,72]", Point(0, 0))
      |> gparsec.token("[", gparsec.ignore_token)
      |> gparsec.integer(fn(value, integer) { Point(..value, x: integer) })
      |> gparsec.token(",", gparsec.ignore_token)
      |> gparsec.integer(fn(value, integer) { Point(..value, y: integer) })
      |> gparsec.token("]", gparsec.ignore_token)
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 7), Point(20, 72)))
    }),
    it("returns a parser that ignored the last integer", fn() {
      new_parser("100;200;400", 0)
      |> gparsec.integer(fn(value, integer) { value + integer })
      |> gparsec.token(";", gparsec.ignore_token)
      |> gparsec.integer(fn(value, integer) { value + integer })
      |> gparsec.token(";", gparsec.ignore_token)
      |> gparsec.integer(gparsec.ignore_integer)
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 11), 300))
    }),
    it("returns an error when being provided an invalid integer", fn() {
      new_parser("not_an_integer", 0)
      |> gparsec.integer(fn(_, integer) { integer })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Pattern("[0-9]"),
        "n",
        ParserPosition(0, 0),
      ))
    }),
    it(
      "returns an error when being provided no further tokens after the sign",
      fn() {
        new_parser("abc-", 0)
        |> gparsec.token("abc", gparsec.ignore_token)
        |> gparsec.integer(fn(_, integer) { integer })
        |> expect.to_be_error()
        |> expect.to_equal(UnexpectedEof(Pattern("[0-9]"), ParserPosition(0, 4)))
      },
    ),
    it("returns an error when a prior parser failed", fn() {
      new_parser("abc2000", 0)
      |> gparsec.token("abd", gparsec.ignore_token)
      |> gparsec.integer(fn(_, integer) { integer })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("abd"),
        "abc",
        ParserPosition(0, 2),
      ))
    }),
    it("returns an error when being provided no tokens", fn() {
      new_parser("", 0)
      |> gparsec.integer(fn(_, integer) { integer })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Pattern("[0-9]"), ParserPosition(0, 0)))
    }),
  ])
}

pub fn float_tests() {
  describe("gparsec/float", [
    it("returns a parser that parsed a positive float", fn() {
      new_parser("250.0", 0.0)
      |> gparsec.float(fn(_, float) { float })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 5), 250.0))
    }),
    it(
      "returns a parser that parsed a positive float with an explicit sign",
      fn() {
        new_parser("+20.4", 0.0)
        |> gparsec.float(fn(_, float) { float })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser([], ParserPosition(0, 5), 20.4))
      },
    ),
    it("returns a parser that parsed a negative float", fn() {
      new_parser("-75.5", 0.0)
      |> gparsec.float(fn(_, float) { float })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 5), -75.5))
    }),
    it(
      "returns a parser that parsed a positive float without an integral part",
      fn() {
        new_parser(".75", 0.0)
        |> gparsec.float(fn(_, float) { float })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser([], ParserPosition(0, 3), 0.75))
      },
    ),
    it(
      "returns a parser that parsed a negative float without an integral part",
      fn() {
        new_parser("-.5", 0.0)
        |> gparsec.float(fn(_, float) { float })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser([], ParserPosition(0, 3), -0.5))
      },
    ),
    it(
      "returns a parser that parsed a float and ignored non-digit tokens afterwards",
      fn() {
        new_parser("5005.25abc", 0.0)
        |> gparsec.float(fn(_, float) { float })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser(
          ["a", "b", "c"],
          ParserPosition(0, 7),
          5005.25,
        ))
      },
    ),
    it(
      "returns a parser that parsed a float and ignored everything after the second decimal point",
      fn() {
        new_parser("25.5.1", 0.0)
        |> gparsec.float(fn(_, float) { float })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser([".", "1"], ParserPosition(0, 4), 25.5))
      },
    ),
    it("returns a parser that parsed multiple floats", fn() {
      new_parser("[20.0,72.4]", Point(0.0, 0.0))
      |> gparsec.token("[", gparsec.ignore_token)
      |> gparsec.float(fn(value, float) { Point(..value, x: float) })
      |> gparsec.token(",", gparsec.ignore_token)
      |> gparsec.float(fn(value, float) { Point(..value, y: float) })
      |> gparsec.token("]", gparsec.ignore_token)
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 11), Point(20.0, 72.4)))
    }),
    it("returns a parser that ignored the last float", fn() {
      new_parser("100.5;200.5;400.0", 0.0)
      |> gparsec.float(fn(value, float) { value +. float })
      |> gparsec.token(";", gparsec.ignore_token)
      |> gparsec.float(fn(value, float) { value +. float })
      |> gparsec.token(";", gparsec.ignore_token)
      |> gparsec.float(gparsec.ignore_float)
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 17), 301.0))
    }),
    it("returns an error when being provided an invalid float", fn() {
      new_parser("not_a_float", 0.0)
      |> gparsec.float(fn(_, float) { float })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Pattern("[0-9.]"),
        "n",
        ParserPosition(0, 0),
      ))
    }),
    it(
      "returns an error when being provided no further tokens after the sign",
      fn() {
        new_parser("abc-", 0.0)
        |> gparsec.token("abc", gparsec.ignore_token)
        |> gparsec.float(fn(_, float) { float })
        |> expect.to_be_error()
        |> expect.to_equal(UnexpectedEof(
          Pattern("[0-9.]"),
          ParserPosition(0, 4),
        ))
      },
    ),
    it("returns an error when a prior parser failed", fn() {
      new_parser("abc2000.0", 0.0)
      |> gparsec.token("abd", gparsec.ignore_token)
      |> gparsec.float(fn(_, float) { float })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("abd"),
        "abc",
        ParserPosition(0, 2),
      ))
    }),
    it("returns an error when being provided no tokens", fn() {
      new_parser("", 0.0)
      |> gparsec.float(fn(_, float) { float })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Pattern("[0-9.]"), ParserPosition(0, 0)))
    }),
  ])
}

pub fn until_tests() {
  describe("gparsec/until", [
    it(
      "returns a parser that parsed all tokens until finding the equal sign",
      fn() {
        new_parser("let test = \"value\";", "")
        |> gparsec.until("=", fn(value, token) { value <> token })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser(
          ["=", " ", "\"", "v", "a", "l", "u", "e", "\"", ";"],
          ParserPosition(0, 9),
          "let test ",
        ))
      },
    ),
    it(
      "returns a parser that parsed all tokens until finding the EQUALS word",
      fn() {
        new_parser("var test EQUALS something", "")
        |> gparsec.until("EQUALS", fn(value, token) { value <> token })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser(
          [
            "E", "Q", "U", "A", "L", "S", " ", "s", "o", "m", "e", "t", "h", "i",
            "n", "g",
          ],
          ParserPosition(0, 9),
          "var test ",
        ))
      },
    ),
    it(
      "returns a parser that parsed all tokens until finding the equal sign multiple times",
      fn() {
        new_parser("let test = \"value\";\nlet test2 = \"value2\";", [])
        |> gparsec.many(until_including_token(
          _,
          "=",
          fn(value, token) { [token, ..value] },
        ))
        |> expect.to_be_ok()
        |> expect.to_equal(
          Parser(
            [" ", "\"", "v", "a", "l", "u", "e", "2", "\"", ";"],
            ParserPosition(1, 11),
            [" \"value\";\nlet test2 ", "let test "],
          ),
        )
      },
    ),
    it("returns an error when the until token could not be found", fn() {
      new_parser("let test value;", "")
      |> gparsec.until("=", fn(value, token) { value <> token })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Literal("="), ParserPosition(0, 15)))
    }),
  ])
}

pub fn skip_until_tests() {
  describe("gparsec/skip_until", [
    it(
      "returns a parser that skipped all tokens until finding the equal sign",
      fn() {
        new_parser("let test = \"value\";", "")
        |> gparsec.skip_until("=")
        |> expect.to_be_ok()
        |> expect.to_equal(Parser(
          ["=", " ", "\"", "v", "a", "l", "u", "e", "\"", ";"],
          ParserPosition(0, 9),
          "",
        ))
      },
    ),
    it(
      "returns a parser that skipped all tokens until finding the EQUALS word",
      fn() {
        new_parser("var test EQUALS something", "")
        |> gparsec.skip_until("EQUALS")
        |> expect.to_be_ok()
        |> expect.to_equal(Parser(
          [
            "E", "Q", "U", "A", "L", "S", " ", "s", "o", "m", "e", "t", "h", "i",
            "n", "g",
          ],
          ParserPosition(0, 9),
          "",
        ))
      },
    ),
    it("returns an error when the until token could not be found", fn() {
      new_parser("let test value;", "")
      |> gparsec.skip_until("=")
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Literal("="), ParserPosition(0, 15)))
    }),
  ])
}

pub fn repeat_tests() {
  describe("gparsec/repeat", [
    it("returns a parser that parsed multiple tokens", fn() {
      new_parser("aaab", [])
      |> gparsec.repeat("", gparsec.token(
        _,
        "a",
        fn(value, token) { value <> token },
      ))
      |> expect.to_be_ok()
      |> expect.to_equal(Parser(["b"], ParserPosition(0, 3), ["a", "a", "a"]))
    }),
    it("returns a parser that parsed no tokens", fn() {
      new_parser("abab", [])
      |> gparsec.repeat("", gparsec.token(
        _,
        "aa",
        fn(value, token) { value <> token },
      ))
      |> gparsec.token("ab", fn(value, token) { [token, ..value] })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser(["a", "b"], ParserPosition(0, 2), ["ab"]))
    }),
    it("returns an error when a prior parser failed", fn() {
      new_parser("aaa", [])
      |> gparsec.token("ab", fn(value, token) { [token, ..value] })
      |> gparsec.repeat("", gparsec.token(
        _,
        "a",
        fn(value, token) { value <> token },
      ))
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("ab"),
        "aa",
        ParserPosition(0, 1),
      ))
    }),
  ])
}

pub fn whitespace_tests() {
  describe("gparsec/whitespace", [
    it("returns a parser that parsed whitespace tokens", fn() {
      new_parser("\t \n", "")
      |> gparsec.whitespace(fn(value, token) { value <> token })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(1, 0), "\t \n"))
    }),
    it(
      "returns a parser that parsed whitespace tokens until encountering the first non-whitespace token",
      fn() {
        new_parser("\t \nabc", "")
        |> gparsec.whitespace(fn(value, token) { value <> token })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser(
          ["a", "b", "c"],
          ParserPosition(1, 0),
          "\t \n",
        ))
      },
    ),
    it(
      "returns a parser that parsed no whitespace tokens since its input started with non-whitespace tokens",
      fn() {
        new_parser("not_whitespace\t \n", "")
        |> gparsec.whitespace(fn(value, token) { value <> token })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser(
          [
            "n", "o", "t", "_", "w", "h", "i", "t", "e", "s", "p", "a", "c", "e",
            "\t", " ", "\n",
          ],
          ParserPosition(0, 0),
          "",
        ))
      },
    ),
    it("returns an error when a prior parser failed", fn() {
      new_parser("ab\t \n", "")
      |> gparsec.token("aa", fn(value, token) { value <> token })
      |> gparsec.whitespace(fn(value, token) { value <> token })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("aa"),
        "ab",
        ParserPosition(0, 1),
      ))
    }),
  ])
}

type Pair {
  Pair(left: String, right: String)
}

type Point(a) {
  Point(x: a, y: a)
}

fn new_parser(input: String, initial_value: a) -> ParserResult(a) {
  Ok(Parser(input |> string.split(""), ParserPosition(0, 0), initial_value))
}

fn until_including_token(
  prev: ParserResult(a),
  token: String,
  to: ParserMapperCallback(a, String),
) -> ParserResult(a) {
  prev
  |> gparsec.until(token, to)
  |> gparsec.token(token, gparsec.ignore_token)
}
