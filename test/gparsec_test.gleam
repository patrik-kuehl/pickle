import gparsec.{
  type ParserMapperCallback, type ParserResult, Parser, ParserPosition,
  UnexpectedEof, UnexpectedToken,
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
      |> expect.to_equal(UnexpectedToken("abdz", "abc", ParserPosition(0, 2)))
    }),
    it("returns an error when encountering an unexpected EOF", fn() {
      gparsec.input("abc", "")
      |> gparsec.token("abcd", fn(value, tokens) { value <> tokens })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof("abcd", ParserPosition(0, 3)))
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
        "what's going on here ...",
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
      |> expect.to_equal(UnexpectedToken("ab", "aa", ParserPosition(0, 1)))
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
      |> expect.to_equal(UnexpectedToken("<integer>", "n", ParserPosition(0, 0)))
    }),
    it(
      "returns an error when being provided no further tokens after the sign",
      fn() {
        gparsec.input("abc-", 0)
        |> gparsec.token("abc", gparsec.ignore_token)
        |> gparsec.integer(fn(_, integer) { integer })
        |> expect.to_be_error()
        |> expect.to_equal(UnexpectedEof("<integer>", ParserPosition(0, 4)))
      },
    ),
    it("returns an error when a prior parser failed", fn() {
      gparsec.input("abc2000", 0)
      |> gparsec.token("abd", gparsec.ignore_token)
      |> gparsec.integer(fn(_, integer) { integer })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken("abd", "abc", ParserPosition(0, 2)))
    }),
    it("returns an error when being provided no tokens", fn() {
      gparsec.input("", 0)
      |> gparsec.integer(fn(_, integer) { integer })
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof("<integer>", ParserPosition(0, 0)))
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
      |> expect.to_equal(UnexpectedEof("=", ParserPosition(0, 15)))
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
      |> expect.to_equal(UnexpectedEof("=", ParserPosition(0, 15)))
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
      |> expect.to_equal(UnexpectedToken("ab", "aa", ParserPosition(0, 1)))
    }),
  ])
}

type Pair {
  Pair(left: String, right: String)
}

type Point {
  Point(x: Int, y: Int)
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
