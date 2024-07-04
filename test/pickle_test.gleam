import gleam/string
import pickle.{
  Eof, GuardError, Literal, ParserPosition, Pattern, UnexpectedEof,
  UnexpectedToken,
}
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn guard_tests() {
  describe("pickle/guard", [
    it("returns an error when the predicate evaluated to false", fn() {
      let error_message = "expected value to equal \"123\""

      pickle.token("abc", fn(value, token) { value <> token })
      |> pickle.then(pickle.guard(fn(value) { value == "123" }, error_message))
      |> pickle.parse("abc", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(GuardError(error_message, ParserPosition(0, 3)))
    }),
    it("returns an error when a prior parser failed", fn() {
      pickle.token("abc", fn(value, token) { value <> token })
      |> pickle.then(pickle.guard(fn(value) { value == "123" }, "error message"))
      |> pickle.parse("abd", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("abc"),
        "abd",
        ParserPosition(0, 2),
      ))
    }),
    it("returns the expected value when the predicate evaluated to true", fn() {
      pickle.token("abc", fn(value, token) { value <> token })
      |> pickle.then(pickle.guard(fn(value) { value == "abc" }, "error message"))
      |> pickle.parse("abc", "", _)
      |> expect.to_be_ok()
      |> expect.to_equal("abc")
    }),
  ])
}

pub fn map_tests() {
  describe("pickle/map", [
    it("returns an error when a prior parser failed", fn() {
      pickle.token("abc", fn(value, token) { value <> token })
      |> pickle.then(pickle.map(fn(value) { string.length(value) }))
      |> pickle.parse("123", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("abc"),
        "1",
        ParserPosition(0, 0),
      ))
    }),
    it("returns the expected value", fn() {
      pickle.token("abc", fn(value, token) { value <> token })
      |> pickle.then(pickle.map(fn(value) { string.length(value) }))
      |> pickle.parse("abc", "", _)
      |> expect.to_be_ok()
      |> expect.to_equal(3)
    }),
  ])
}

pub fn token_tests() {
  describe("pickle/token", [
    it("returns an error when a prior parser failed", fn() {
      pickle.token("123", fn(value, token) { value <> token })
      |> pickle.then(pickle.token("abc", fn(value, token) { value <> token }))
      |> pickle.parse("abc", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("123"),
        "a",
        ParserPosition(0, 0),
      ))
    }),
    it("returns an error when encountering an unexpected token", fn() {
      pickle.token("abcd", fn(value, token) { value <> token })
      |> pickle.parse("abce", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("abcd"),
        "abce",
        ParserPosition(0, 3),
      ))
    }),
    it("returns an error when encountering an unexpected EOF", fn() {
      pickle.token("abc", fn(value, token) { value <> token })
      |> pickle.parse("", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Literal("abc"), ParserPosition(0, 0)))
    }),
    it("returns the expected value", fn() {
      pickle.token("input", fn(value, token) { value <> token })
      |> pickle.parse("input", "", _)
      |> expect.to_be_ok()
      |> expect.to_equal("input")
    }),
  ])
}

pub fn optional_tests() {
  describe("pickle/optional", [
    it("returns an error when a prior parser failed", fn() {
      pickle.optional(pickle.token("(", pickle.ignore_token))
      |> pickle.then(pickle.token("abc", fn(value, token) { value <> token }))
      |> pickle.then(
        pickle.optional(
          pickle.token("123", fn(value, token) { value <> token }),
        ),
      )
      |> pickle.parse("(abd123", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("abc"),
        "abd",
        ParserPosition(0, 3),
      ))
    }),
    it("returns the expected value after parsing optional tokens", fn() {
      pickle.optional(pickle.token("(", pickle.ignore_token))
      |> pickle.then(pickle.token("value", fn(value, token) { value <> token }))
      |> pickle.then(pickle.optional(pickle.token(")", pickle.ignore_token)))
      |> pickle.parse("(value)", "", _)
      |> expect.to_be_ok()
      |> expect.to_equal("value")
    }),
    it(
      "returns the expected value after skipping missing optional tokens",
      fn() {
        pickle.optional(pickle.token("(", fn(value, token) { value <> token }))
        |> pickle.then(
          pickle.token("value", fn(value, token) { value <> token }),
        )
        |> pickle.then(pickle.optional(pickle.token(")", pickle.ignore_token)))
        |> pickle.parse("value)", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("value")
      },
    ),
  ])
}

pub fn many_tests() {
  describe("pickle/many", [
    it("returns an error when a prior parser failed", fn() {
      pickle.token("ab", fn(value, token) { [token, ..value] })
      |> pickle.then(
        pickle.many(
          "",
          pickle.token("a", fn(value, token) { value <> token }),
          fn(value, token) { [token, ..value] },
        ),
      )
      |> pickle.parse("aaa", [], _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("ab"),
        "aa",
        ParserPosition(0, 1),
      ))
    }),
    it("returns the expected value after parsing multiple tokens", fn() {
      pickle.many(
        "",
        pickle.token("a", fn(value, token) { value <> token }),
        fn(value, token) { [token, ..value] },
      )
      |> pickle.parse("aaab", [], _)
      |> expect.to_be_ok()
      |> expect.to_equal(["a", "a", "a"])
    }),
    it("returns the expected value after parsing no tokens", fn() {
      pickle.many(
        "",
        pickle.token("aa", fn(value, token) { value <> token }),
        fn(value, token) { [token, ..value] },
      )
      |> pickle.then(pickle.token("ab", fn(value, token) { [token, ..value] }))
      |> pickle.parse("abab", [], _)
      |> expect.to_be_ok()
      |> expect.to_equal(["ab"])
    }),
  ])
}

pub fn integer_tests() {
  describe("pickle/integer", [
    it("returns an error when being provided an invalid integer", fn() {
      pickle.integer(fn(_, integer) { integer })
      |> pickle.parse("not_an_integer", 0, _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Pattern("^[0-9]$"),
        "n",
        ParserPosition(0, 0),
      ))
    }),
    it(
      "returns an error when being provided no further tokens after the sign",
      fn() {
        pickle.token("abc", pickle.ignore_token)
        |> pickle.then(pickle.integer(fn(_, integer) { integer }))
        |> pickle.parse("abc-", 0, _)
        |> expect.to_be_error()
        |> expect.to_equal(UnexpectedEof(
          Pattern("^[0-9]$"),
          ParserPosition(0, 4),
        ))
      },
    ),
    it("returns an error when a prior parser failed", fn() {
      pickle.token("abd", pickle.ignore_token)
      |> pickle.then(pickle.integer(fn(_, integer) { integer }))
      |> pickle.parse("abc2000", 0, _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("abd"),
        "abc",
        ParserPosition(0, 2),
      ))
    }),
    it("returns an error when encountering an unexpected EOF", fn() {
      pickle.integer(fn(_, integer) { integer })
      |> pickle.parse("", 0, _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Pattern("^[0-9]$"), ParserPosition(0, 0)))
    }),
    it("returns the expected value after parsing a positive integer", fn() {
      pickle.integer(fn(_, integer) { integer })
      |> pickle.parse("250", 0, _)
      |> expect.to_be_ok()
      |> expect.to_equal(250)
    }),
    it(
      "returns the expected value after parsing a positive integer with an explicit sign",
      fn() {
        pickle.integer(fn(_, integer) { integer })
        |> pickle.parse("+120", 0, _)
        |> expect.to_be_ok()
        |> expect.to_equal(120)
      },
    ),
    it("returns the expected value after parsing a negative integer", fn() {
      pickle.integer(fn(_, integer) { integer })
      |> pickle.parse("-75", 0, _)
      |> expect.to_be_ok()
      |> expect.to_equal(-75)
    }),
    it(
      "returns the expected value after parsing an integer while ignoring non-digit tokens afterwards",
      fn() {
        pickle.integer(fn(_, integer) { integer })
        |> pickle.parse("5005abc", 0, _)
        |> expect.to_be_ok()
        |> expect.to_equal(5005)
      },
    ),
    it("returns the expected value after parsing multiple integers", fn() {
      pickle.token("[", pickle.ignore_token)
      |> pickle.then(
        pickle.integer(fn(value, integer) { Point(..value, x: integer) }),
      )
      |> pickle.then(pickle.token(",", pickle.ignore_token))
      |> pickle.then(
        pickle.integer(fn(value, integer) { Point(..value, y: integer) }),
      )
      |> pickle.then(pickle.token("]", pickle.ignore_token))
      |> pickle.parse("[20,72]", Point(0, 0), _)
      |> expect.to_be_ok()
      |> expect.to_equal(Point(20, 72))
    }),
    it(
      "returns the expected value after parsing integers while ignoring the last integer",
      fn() {
        pickle.integer(fn(value, integer) { value + integer })
        |> pickle.then(pickle.token(";", pickle.ignore_token))
        |> pickle.then(pickle.integer(fn(value, integer) { value + integer }))
        |> pickle.then(pickle.token(";", pickle.ignore_token))
        |> pickle.then(pickle.integer(pickle.ignore_integer))
        |> pickle.parse("100;200;400", 0, _)
        |> expect.to_be_ok()
        |> expect.to_equal(300)
      },
    ),
  ])
}

pub fn float_tests() {
  describe("pickle/float", [
    it("returns an error when being provided an invalid float", fn() {
      pickle.float(fn(_, float) { float })
      |> pickle.parse("not_a_float", 0.0, _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Pattern("^[0-9.]$"),
        "n",
        ParserPosition(0, 0),
      ))
    }),
    it(
      "returns an error when being provided no further tokens after the sign",
      fn() {
        pickle.token("abc", pickle.ignore_token)
        |> pickle.then(pickle.float(fn(_, float) { float }))
        |> pickle.parse("abc-", 0.0, _)
        |> expect.to_be_error()
        |> expect.to_equal(UnexpectedEof(
          Pattern("^[0-9.]$"),
          ParserPosition(0, 4),
        ))
      },
    ),
    it("returns an error when a prior parser failed", fn() {
      pickle.token("abd", pickle.ignore_token)
      |> pickle.then(pickle.float(fn(_, float) { float }))
      |> pickle.parse("abc2000.0", 0.0, _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("abd"),
        "abc",
        ParserPosition(0, 2),
      ))
    }),
    it("returns an error when being provided no tokens", fn() {
      pickle.float(fn(_, float) { float })
      |> pickle.parse("", 0.0, _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(
        Pattern("^[0-9.]$"),
        ParserPosition(0, 0),
      ))
    }),
    it("returns the expected value after parsing a positive float", fn() {
      pickle.float(fn(_, float) { float })
      |> pickle.parse("250.0", 0.0, _)
      |> expect.to_be_ok()
      |> expect.to_equal(250.0)
    }),
    it(
      "returns the expected value after parsing a positive float with an explicit sign",
      fn() {
        pickle.float(fn(_, float) { float })
        |> pickle.parse("+20.4", 0.0, _)
        |> expect.to_be_ok()
        |> expect.to_equal(20.4)
      },
    ),
    it("returns the expected value after parsing a negative float", fn() {
      pickle.float(fn(_, float) { float })
      |> pickle.parse("-75.5", 0.0, _)
      |> expect.to_be_ok()
      |> expect.to_equal(-75.5)
    }),
    it(
      "returns the expected value after parsing a positive float without an integral part",
      fn() {
        pickle.float(fn(_, float) { float })
        |> pickle.parse(".75", 0.0, _)
        |> expect.to_be_ok()
        |> expect.to_equal(0.75)
      },
    ),
    it(
      "returns the expected value after parsing a negative float without an integral part",
      fn() {
        pickle.float(fn(_, float) { float })
        |> pickle.parse("-.5", 0.0, _)
        |> expect.to_be_ok()
        |> expect.to_equal(-0.5)
      },
    ),
    it(
      "returns the expected value after parsing a float while ignoring non-digit tokens afterwards",
      fn() {
        pickle.float(fn(_, float) { float })
        |> pickle.parse("5005.25abc", 0.0, _)
        |> expect.to_be_ok()
        |> expect.to_equal(5005.25)
      },
    ),
    it(
      "returns the expected value after parsing a float while ignoring everything from the second decimal point",
      fn() {
        pickle.float(fn(_, float) { float })
        |> pickle.parse("25.5.1", 0.0, _)
        |> expect.to_be_ok()
        |> expect.to_equal(25.5)
      },
    ),
    it("returns the expected value after parsing multiple floats", fn() {
      pickle.token("[", pickle.ignore_token)
      |> pickle.then(
        pickle.float(fn(value, float) { Point(..value, x: float) }),
      )
      |> pickle.then(pickle.token(",", pickle.ignore_token))
      |> pickle.then(
        pickle.float(fn(value, float) { Point(..value, y: float) }),
      )
      |> pickle.then(pickle.token("]", pickle.ignore_token))
      |> pickle.parse("[20.0,72.4]", Point(0.0, 0.0), _)
      |> expect.to_be_ok()
      |> expect.to_equal(Point(20.0, 72.4))
    }),
    it(
      "returns the expected value after parsing floats while ignoring the last float",
      fn() {
        pickle.float(fn(value, float) { value +. float })
        |> pickle.then(pickle.token(";", pickle.ignore_token))
        |> pickle.then(pickle.float(fn(value, float) { value +. float }))
        |> pickle.then(pickle.token(";", pickle.ignore_token))
        |> pickle.then(pickle.float(pickle.ignore_float))
        |> pickle.parse("100.5;200.5;400.0", 0.0, _)
        |> expect.to_be_ok()
        |> expect.to_equal(301.0)
      },
    ),
  ])
}

pub fn until_tests() {
  describe("pickle/until", [
    it("returns an error when the until token could not be found", fn() {
      pickle.until("=", fn(value, token) { value <> token })
      |> pickle.parse("let test value;", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Literal("="), ParserPosition(0, 15)))
    }),
    it(
      "returns the expected value after parsing all tokens until finding the equal sign",
      fn() {
        pickle.until("=", fn(value, token) { value <> token })
        |> pickle.parse("let test = \"value\";", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("let test ")
      },
    ),
    it(
      "returns the expected value after parsing all tokens until finding the EQUALS word",
      fn() {
        pickle.until("EQUALS", fn(value, token) { value <> token })
        |> pickle.parse("var test EQUALS something", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("var test ")
      },
    ),
    it(
      "returns the expected value after parsing all tokens until finding the equal sign multiple times",
      fn() {
        pickle.many(
          "",
          pickle.until("=", fn(value, token) { value <> token })
            |> pickle.then(pickle.token("=", pickle.ignore_token)),
          fn(value, token) { [token, ..value] },
        )
        |> pickle.parse("let test = \"value\";\nlet test2 = \"value2\";", [], _)
        |> expect.to_be_ok()
        |> expect.to_equal([" \"value\";\nlet test2 ", "let test "])
      },
    ),
  ])
}

pub fn skip_until_tests() {
  describe("pickle/skip_until", [
    it("returns an error when the until token could not be found", fn() {
      pickle.skip_until("=")
      |> pickle.parse("let test value;", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedEof(Literal("="), ParserPosition(0, 15)))
    }),
    it(
      "returns the expected value after skipping all tokens until finding the equal sign",
      fn() {
        pickle.skip_until("=")
        |> pickle.then(pickle.until(";", fn(value, token) { value <> token }))
        |> pickle.parse("let test = \"value\";", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("= \"value\"")
      },
    ),
    it(
      "returns the expected value after skipping all tokens until finding the EQUALS word",
      fn() {
        pickle.skip_until("EQUALS")
        |> pickle.then(pickle.until(" ", fn(value, token) { value <> token }))
        |> pickle.parse("var test EQUALS something", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("EQUALS")
      },
    ),
  ])
}

pub fn whitespace_tests() {
  describe("pickle/whitespace", [
    it("returns an error when a prior parser failed", fn() {
      pickle.token("aa", fn(value, token) { value <> token })
      |> pickle.then(pickle.whitespace(fn(value, token) { value <> token }))
      |> pickle.parse("ab\t \n", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("aa"),
        "ab",
        ParserPosition(0, 1),
      ))
    }),
    it("returns the expected value after parsing whitespace tokens", fn() {
      pickle.whitespace(fn(value, token) { value <> token })
      |> pickle.parse("\t \n", "", _)
      |> expect.to_be_ok()
      |> expect.to_equal("\t \n")
    }),
    it(
      "returns the expected value after parsing whitespace tokens until encountering the first non-whitespace token",
      fn() {
        pickle.whitespace(fn(value, token) { value <> token })
        |> pickle.parse("\t \nabc", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("\t \n")
      },
    ),
    it(
      "returns the expected value after parsing no whitespace tokens since its input started with non-whitespace tokens",
      fn() {
        pickle.whitespace(fn(value, token) { value <> token })
        |> pickle.parse("not_whitespace\t \n", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("")
      },
    ),
  ])
}

pub fn skip_whitespace_tests() {
  describe("pickle/skip_whitespace", [
    it("returns an error when a prior parser failed", fn() {
      pickle.token("aa", fn(value, token) { value <> token })
      |> pickle.then(pickle.skip_whitespace())
      |> pickle.parse("ab\t \n", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("aa"),
        "ab",
        ParserPosition(0, 1),
      ))
    }),
    it(
      "returns the expected value after skipping all tokens until finding the first non-whitespace token",
      fn() {
        pickle.token("something", fn(value, token) { value <> token })
        |> pickle.then(pickle.skip_whitespace())
        |> pickle.parse("something\t \n abc", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("something")
      },
    ),
    it(
      "returns the expected value after skipping no whitespace tokens since its input started with non-whitespace tokens",
      fn() {
        pickle.skip_whitespace()
        |> pickle.parse("not_whitespace\t \n", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("")
      },
    ),
  ])
}

pub fn one_of_tests() {
  describe("pickle/one_of", [
    it(
      "returns the error of the last failed parser when no given parser succeeded",
      fn() {
        pickle.one_of([
          pickle.token("abc", fn(value, token) { value <> token }),
          pickle.token("abd", fn(value, token) { value <> token }),
        ])
        |> pickle.parse("ade", "", _)
        |> expect.to_be_error()
        |> expect.to_equal(UnexpectedToken(
          Literal("abd"),
          "ad",
          ParserPosition(0, 1),
        ))
      },
    ),
    it("returns an error when a prior parser failed", fn() {
      pickle.token("123", fn(value, token) { value <> token })
      |> pickle.then(
        pickle.one_of([
          pickle.token("abc", fn(value, token) { value <> token }),
          pickle.token("abd", fn(value, token) { value <> token }),
        ]),
      )
      |> pickle.parse("abc", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("123"),
        "a",
        ParserPosition(0, 0),
      ))
    }),
    it(
      "returns the expected value after parsing multiple tokens when the first given parser succeeded",
      fn() {
        pickle.one_of([
          pickle.token("abc", fn(value, token) { value <> token }),
          pickle.token("abd", fn(value, token) { value <> token }),
        ])
        |> pickle.parse("abc", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("abc")
      },
    ),
    it(
      "returns the expected value after parsing multiple tokens when the second given parser succeeded",
      fn() {
        pickle.one_of([
          pickle.token("abc", fn(value, token) { value <> token }),
          pickle.token("abd", fn(value, token) { value <> token }),
        ])
        |> pickle.parse("abd", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("abd")
      },
    ),
    it(
      "returns the expected value after parsing no tokens when not being provided any parsers",
      fn() {
        pickle.one_of([])
        |> pickle.parse("abc", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("")
      },
    ),
  ])
}

pub fn return_tests() {
  describe("pickle/return", [
    it("returns an error when a prior parser failed", fn() {
      pickle.token("abd", fn(value, token) { [token, ..value] })
      |> pickle.then(pickle.return(10))
      |> pickle.parse("abc", [], _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("abd"),
        "abc",
        ParserPosition(0, 2),
      ))
    }),
    it("returns the expected value", fn() {
      pickle.token("abc", fn(value, token) { [token, ..value] })
      |> pickle.then(pickle.return(20))
      |> pickle.parse("abc", [], _)
      |> expect.to_be_ok()
      |> expect.to_equal(20)
    }),
  ])
}

pub fn eof_tests() {
  describe("pickle/eof", [
    it("returns an error when there are tokens left to parse", fn() {
      pickle.token("abc", fn(value, token) { value <> token })
      |> pickle.then(pickle.eof())
      |> pickle.parse("abcd", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(Eof, "d", ParserPosition(0, 3)))
    }),
    it("returns an error when a prior parser failed", fn() {
      pickle.token("ab\nd", fn(value, token) { value <> token })
      |> pickle.then(pickle.eof())
      |> pickle.parse("ab\nc", "", _)
      |> expect.to_be_error()
      |> expect.to_equal(UnexpectedToken(
        Literal("ab\nd"),
        "ab\nc",
        ParserPosition(1, 0),
      ))
    }),
    it(
      "returns the expected value when there are no tokens left to parse",
      fn() {
        pickle.token("abc", fn(value, token) { value <> token })
        |> pickle.then(pickle.eof())
        |> pickle.parse("abc", "", _)
        |> expect.to_be_ok()
        |> expect.to_equal("abc")
      },
    ),
  ])
}

type Point(a) {
  Point(x: a, y: a)
}
