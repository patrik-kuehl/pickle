import gparsec.{
  type ParserMapperCallback, type ParserResult, Digit, DigitOrDecimalPoint,
  Parser, ParserPosition, Token, UnexpectedEof, UnexpectedToken,
}
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn input_tests() {
  describe("gparsec/input", [
    it("returns a new parser", fn() {
      gparsec.input("abc", [])
      |> expect.to_be_ok()
      |> expect.to_equal(Parser(["a", "b", "c"], ParserPosition(0, 0), []))
    }),
  ])
}

pub fn token_tests() {
  describe("gparsec/token", [
    it("returns a parser that parsed a single token", fn() {
      gparsec.input("abc", "Characters: ")
      |> gparsec.token("a", fn(value, token) { value <> token })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser(
        ["b", "c"],
        ParserPosition(0, 1),
        "Characters: a",
      ))
    }),
    it("returns a parser that parsed a set of tokens", fn() {
      gparsec.input("abcdefg", "Characters: ")
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
      gparsec.input("abc\ndef", "Characters: ")
      |> gparsec.token("abc", fn(value, tokens) { value <> tokens })
      |> gparsec.token("\n", gparsec.ignore_token)
      |> gparsec.token("def", fn(value, tokens) { value <> tokens })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(1, 3), "Characters: abcdef"))
    }),
    it("returns an error when encountering an unexpected token", fn() {
      gparsec.input("abcd", "")
      |> gparsec.token("abdz", fn(value, tokens) { value <> tokens })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Token("abdz"),
        "abc",
        ParserPosition(0, 2),
      ))
    }),
    it("returns an error when encountering an unexpected EOF", fn() {
      gparsec.input("abc", "")
      |> gparsec.token("abcd", fn(value, tokens) { value <> tokens })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Token("abcd"), ParserPosition(0, 3)))
    }),
  ])
}

pub fn optional_tests() {
  describe("gparsec/optional", [
    it(
      "returns a parser that parsed a set of tokens including some optional tokens",
      fn() {
        gparsec.input("(a,b)", Pair("", ""))
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
        gparsec.input("a,b)", Pair("", ""))
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
      gparsec.input("(a,b)", Pair("", ""))
      |> gparsec.token("what's going on here ...", gparsec.ignore_token)
      |> gparsec.optional(gparsec.token(_, "(", gparsec.ignore_token))
      |> gparsec.token("a", fn(value, token) { Pair(..value, left: token) })
      |> gparsec.token(",", gparsec.ignore_token)
      |> gparsec.token("b", fn(value, token) { Pair(..value, right: token) })
      |> gparsec.optional(gparsec.token(_, ")", gparsec.ignore_token))
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Token("what's going on here ..."),
        "(",
        ParserPosition(0, 0),
      ))
    }),
  ])
}

pub fn many_tests() {
  describe("gparsec/many", [
    it("returns a parser that parsed multiple tokens", fn() {
      gparsec.input("aaab", "Characters: ")
      |> gparsec.many(gparsec.token(_, "a", fn(value, token) { value <> token }))
      |> expect.to_be_ok()
      |> expect.to_equal(Parser(["b"], ParserPosition(0, 3), "Characters: aaa"))
    }),
    it("returns a parser that parsed no tokens", fn() {
      gparsec.input("abab", "Characters: ")
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
      gparsec.input("aaa", "Characters: ")
      |> gparsec.token("ab", fn(value, token) { value <> token })
      |> gparsec.many(gparsec.token(_, "a", fn(value, token) { value <> token }))
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Token("ab"),
        "aa",
        ParserPosition(0, 1),
      ))
    }),
  ])
}

pub fn integer_tests() {
  describe("gparsec/integer", [
    it("returns a parser that parsed a positive integer", fn() {
      gparsec.input("250", 0)
      |> gparsec.integer(fn(_, integer) { integer })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 3), 250))
    }),
    it(
      "returns a parser that parsed a positive integer with an explicit sign",
      fn() {
        gparsec.input("+120", 0)
        |> gparsec.integer(fn(_, integer) { integer })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser([], ParserPosition(0, 4), 120))
      },
    ),
    it("returns a parser that parsed a negative integer", fn() {
      gparsec.input("-75", 0)
      |> gparsec.integer(fn(_, integer) { integer })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 3), -75))
    }),
    it(
      "returns a parser that parsed an integer and ignored non-digit tokens afterwards",
      fn() {
        gparsec.input("5005abc", 0)
        |> gparsec.integer(fn(_, integer) { integer })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser(["a", "b", "c"], ParserPosition(0, 4), 5005))
      },
    ),
    it("returns a parser that parsed multiple integers", fn() {
      gparsec.input("[20,72]", Point(0, 0))
      |> gparsec.token("[", gparsec.ignore_token)
      |> gparsec.integer(fn(value, integer) { Point(..value, x: integer) })
      |> gparsec.token(",", gparsec.ignore_token)
      |> gparsec.integer(fn(value, integer) { Point(..value, y: integer) })
      |> gparsec.token("]", gparsec.ignore_token)
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 7), Point(20, 72)))
    }),
    it("returns a parser that ignored the last integer", fn() {
      gparsec.input("100;200;400", 0)
      |> gparsec.integer(fn(value, integer) { value + integer })
      |> gparsec.token(";", gparsec.ignore_token)
      |> gparsec.integer(fn(value, integer) { value + integer })
      |> gparsec.token(";", gparsec.ignore_token)
      |> gparsec.integer(gparsec.ignore_integer)
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 11), 300))
    }),
    it("returns an error when being provided an invalid integer", fn() {
      gparsec.input("not_an_integer", 0)
      |> gparsec.integer(fn(_, integer) { integer })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(Digit, "n", ParserPosition(0, 0)))
    }),
    it(
      "returns an error when being provided no further tokens after the sign",
      fn() {
        gparsec.input("abc-", 0)
        |> gparsec.token("abc", gparsec.ignore_token)
        |> gparsec.integer(fn(_, integer) { integer })
        |> expect.to_be_error()
        |> expect.to_equal(UnexpectedEof(Digit, ParserPosition(0, 4)))
      },
    ),
    it("returns an error when a prior parser failed", fn() {
      gparsec.input("abc2000", 0)
      |> gparsec.token("abd", gparsec.ignore_token)
      |> gparsec.integer(fn(_, integer) { integer })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Token("abd"),
        "abc",
        ParserPosition(0, 2),
      ))
    }),
    it("returns an error when being provided no tokens", fn() {
      gparsec.input("", 0)
      |> gparsec.integer(fn(_, integer) { integer })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Digit, ParserPosition(0, 0)))
    }),
  ])
}

pub fn float_tests() {
  describe("gparsec/float", [
    it("returns a parser that parsed a positive float", fn() {
      gparsec.input("250.0", 0.0)
      |> gparsec.float(fn(_, float) { float })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 5), 250.0))
    }),
    it(
      "returns a parser that parsed a positive float with an explicit sign",
      fn() {
        gparsec.input("+20.4", 0.0)
        |> gparsec.float(fn(_, float) { float })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser([], ParserPosition(0, 5), 20.4))
      },
    ),
    it("returns a parser that parsed a negative float", fn() {
      gparsec.input("-75.5", 0.0)
      |> gparsec.float(fn(_, float) { float })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 5), -75.5))
    }),
    it(
      "returns a parser that parsed a positive float without an integral part",
      fn() {
        gparsec.input(".75", 0.0)
        |> gparsec.float(fn(_, float) { float })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser([], ParserPosition(0, 3), 0.75))
      },
    ),
    it(
      "returns a parser that parsed a negative float without an integral part",
      fn() {
        gparsec.input("-.5", 0.0)
        |> gparsec.float(fn(_, float) { float })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser([], ParserPosition(0, 3), -0.5))
      },
    ),
    it(
      "returns a parser that parsed a float and ignored non-digit tokens afterwards",
      fn() {
        gparsec.input("5005.25abc", 0.0)
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
        gparsec.input("25.5.1", 0.0)
        |> gparsec.float(fn(_, float) { float })
        |> expect.to_be_ok()
        |> expect.to_equal(Parser([".", "1"], ParserPosition(0, 4), 25.5))
      },
    ),
    it("returns a parser that parsed multiple floats", fn() {
      gparsec.input("[20.0,72.4]", Point(0.0, 0.0))
      |> gparsec.token("[", gparsec.ignore_token)
      |> gparsec.float(fn(value, float) { Point(..value, x: float) })
      |> gparsec.token(",", gparsec.ignore_token)
      |> gparsec.float(fn(value, float) { Point(..value, y: float) })
      |> gparsec.token("]", gparsec.ignore_token)
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 11), Point(20.0, 72.4)))
    }),
    it("returns a parser that ignored the last float", fn() {
      gparsec.input("100.5;200.5;400.0", 0.0)
      |> gparsec.float(fn(value, float) { value +. float })
      |> gparsec.token(";", gparsec.ignore_token)
      |> gparsec.float(fn(value, float) { value +. float })
      |> gparsec.token(";", gparsec.ignore_token)
      |> gparsec.float(gparsec.ignore_float)
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(0, 17), 301.0))
    }),
    it("returns an error when being provided an invalid float", fn() {
      gparsec.input("not_a_float", 0.0)
      |> gparsec.float(fn(_, float) { float })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        DigitOrDecimalPoint,
        "n",
        ParserPosition(0, 0),
      ))
    }),
    it(
      "returns an error when being provided no further tokens after the sign",
      fn() {
        gparsec.input("abc-", 0.0)
        |> gparsec.token("abc", gparsec.ignore_token)
        |> gparsec.float(fn(_, float) { float })
        |> expect.to_be_error()
        |> expect.to_equal(UnexpectedEof(
          DigitOrDecimalPoint,
          ParserPosition(0, 4),
        ))
      },
    ),
    it("returns an error when a prior parser failed", fn() {
      gparsec.input("abc2000.0", 0.0)
      |> gparsec.token("abd", gparsec.ignore_token)
      |> gparsec.float(fn(_, float) { float })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Token("abd"),
        "abc",
        ParserPosition(0, 2),
      ))
    }),
    it("returns an error when being provided no tokens", fn() {
      gparsec.input("", 0.0)
      |> gparsec.float(fn(_, float) { float })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(
        DigitOrDecimalPoint,
        ParserPosition(0, 0),
      ))
    }),
  ])
}

pub fn until_tests() {
  describe("gparsec/until", [
    it(
      "returns a parser that parsed all tokens until finding the equal sign",
      fn() {
        gparsec.input("let test = \"value\";", "")
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
        gparsec.input("var test EQUALS something", "")
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
        gparsec.input("let test = \"value\";\nlet test2 = \"value2\";", [])
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
      gparsec.input("let test value;", "")
      |> gparsec.until("=", fn(value, token) { value <> token })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Token("="), ParserPosition(0, 15)))
    }),
  ])
}

pub fn skip_until_tests() {
  describe("gparsec/skip_until", [
    it(
      "returns a parser that skipped all tokens until finding the equal sign",
      fn() {
        gparsec.input("let test = \"value\";", "")
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
        gparsec.input("var test EQUALS something", "")
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
      gparsec.input("let test value;", "")
      |> gparsec.skip_until("=")
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Token("="), ParserPosition(0, 15)))
    }),
  ])
}

pub fn repeat_tests() {
  describe("gparsec/repeat", [
    it("returns a parser that parsed multiple tokens", fn() {
      gparsec.input("aaab", [])
      |> gparsec.repeat("", gparsec.token(
        _,
        "a",
        fn(value, token) { value <> token },
      ))
      |> expect.to_be_ok()
      |> expect.to_equal(Parser(["b"], ParserPosition(0, 3), ["a", "a", "a"]))
    }),
    it("returns a parser that parsed no tokens", fn() {
      gparsec.input("abab", [])
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
      gparsec.input("aaa", [])
      |> gparsec.token("ab", fn(value, token) { [token, ..value] })
      |> gparsec.repeat("", gparsec.token(
        _,
        "a",
        fn(value, token) { value <> token },
      ))
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Token("ab"),
        "aa",
        ParserPosition(0, 1),
      ))
    }),
  ])
}

pub fn whitespace_tests() {
  describe("gparsec/whitespace", [
    it("returns a parser that parsed whitespace tokens", fn() {
      gparsec.input("\t \n", "")
      |> gparsec.whitespace(fn(value, token) { value <> token })
      |> expect.to_be_ok()
      |> expect.to_equal(Parser([], ParserPosition(1, 0), "\t \n"))
    }),
    it(
      "returns a parser that parsed whitespace tokens until encountering the first non-whitespace token",
      fn() {
        gparsec.input("\t \nabc", "")
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
        gparsec.input("not_whitespace\t \n", "")
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
      gparsec.input("ab\t \n", "")
      |> gparsec.token("aa", fn(value, token) { value <> token })
      |> gparsec.whitespace(fn(value, token) { value <> token })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Token("aa"),
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

fn until_including_token(
  prev: ParserResult(a),
  token: String,
  to: ParserMapperCallback(a, String),
) -> ParserResult(a) {
  prev
  |> gparsec.until(token, to)
  |> gparsec.token(token, gparsec.ignore_token)
}
