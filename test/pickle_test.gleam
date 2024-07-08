import gleam/string
import gleeunit
import gleeunit/should
import pickle.{
  Eof, GuardError, Literal, OneOfError, ParserPosition, Pattern, UnexpectedEof,
  UnexpectedToken,
}

pub fn main() {
  gleeunit.main()
}

pub fn guard_test() {
  let error_message = "expected value to equal \"123\""

  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.guard(fn(value) { value == "123" }, error_message))
  |> pickle.parse("abc", "", _)
  |> should.be_error()
  |> should.equal(GuardError(error_message, ParserPosition(0, 3)))

  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.guard(fn(value) { value == "123" }, "error message"))
  |> pickle.parse("abd", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Literal("abc"), "abd", ParserPosition(0, 2)))

  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.guard(fn(value) { value == "abc" }, "error message"))
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal("abc")
}

pub fn map_test() {
  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.map(fn(value) { string.length(value) }))
  |> pickle.parse("a23", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Literal("abc"), "a2", ParserPosition(0, 1)))

  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.map(fn(value) { string.length(value) }))
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal(3)
}

pub fn string_test() {
  pickle.string("123", fn(value, string) { value <> string })
  |> pickle.then(pickle.string("abc", fn(value, string) { value <> string }))
  |> pickle.parse("abc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Literal("123"), "a", ParserPosition(0, 0)))

  pickle.string("a\nb", fn(value, string) { value <> string })
  |> pickle.parse("a\nc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Literal("a\nb"), "a\nc", ParserPosition(1, 0)))

  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.parse("", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(Literal("abc"), ParserPosition(0, 0)))

  pickle.string("input", fn(value, string) { value <> string })
  |> pickle.parse("input", "", _)
  |> should.be_ok()
  |> should.equal("input")
}

pub fn optional_test() {
  pickle.optional(pickle.string("(", pickle.ignore_string))
  |> pickle.then(pickle.string("abc", fn(value, string) { value <> string }))
  |> pickle.then(
    pickle.optional(pickle.string("123", fn(value, string) { value <> string })),
  )
  |> pickle.parse("(abd123", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Literal("abc"), "abd", ParserPosition(0, 3)))

  pickle.optional(pickle.string("(", pickle.ignore_string))
  |> pickle.then(pickle.string("value", fn(value, string) { value <> string }))
  |> pickle.then(pickle.optional(pickle.string(")", pickle.ignore_string)))
  |> pickle.parse("(value)", "", _)
  |> should.be_ok()
  |> should.equal("value")

  pickle.optional(pickle.string("(", fn(value, string) { value <> string }))
  |> pickle.then(pickle.string("value", fn(value, string) { value <> string }))
  |> pickle.then(pickle.optional(pickle.string(")", pickle.ignore_string)))
  |> pickle.parse("value)", "", _)
  |> should.be_ok()
  |> should.equal("value")
}

pub fn many_test() {
  pickle.string("ab", fn(value, string) { [string, ..value] })
  |> pickle.then(
    pickle.many(
      "",
      pickle.string("a", fn(value, string) { value <> string }),
      fn(value, string) { [string, ..value] },
    ),
  )
  |> pickle.parse("aaa", [], _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Literal("ab"), "aa", ParserPosition(0, 1)))

  pickle.many(
    "",
    pickle.string("a", fn(value, string) { value <> string }),
    fn(value, string) { [string, ..value] },
  )
  |> pickle.parse("aaab", [], _)
  |> should.be_ok()
  |> should.equal(["a", "a", "a"])

  pickle.many(
    "",
    pickle.string("aa", fn(value, string) { value <> string }),
    fn(value, string) { [string, ..value] },
  )
  |> pickle.then(pickle.string("ab", fn(value, string) { [string, ..value] }))
  |> pickle.parse("abab", [], _)
  |> should.be_ok()
  |> should.equal(["ab"])
}

pub fn integer_test() {
  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("not_an_integer", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Pattern("^[0-9]$"), "n", ParserPosition(0, 0)))

  pickle.string("abc", pickle.ignore_string)
  |> pickle.then(pickle.integer(fn(_, integer) { integer }))
  |> pickle.parse("abc-", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(Pattern("^[0-9]$"), ParserPosition(0, 4)))

  pickle.string("abd", pickle.ignore_string)
  |> pickle.then(pickle.integer(fn(_, integer) { integer }))
  |> pickle.parse("abc2000", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Literal("abd"), "abc", ParserPosition(0, 2)))

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(Pattern("^[0-9]$"), ParserPosition(0, 0)))

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("250", 0, _)
  |> should.be_ok()
  |> should.equal(250)

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("+120", 0, _)
  |> should.be_ok()
  |> should.equal(120)

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("-75", 0, _)
  |> should.be_ok()
  |> should.equal(-75)

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("5005abc", 0, _)
  |> should.be_ok()
  |> should.equal(5005)

  pickle.string("[", pickle.ignore_string)
  |> pickle.then(
    pickle.integer(fn(value, integer) { Point(..value, x: integer) }),
  )
  |> pickle.then(pickle.string(",", pickle.ignore_string))
  |> pickle.then(
    pickle.integer(fn(value, integer) { Point(..value, y: integer) }),
  )
  |> pickle.then(pickle.string("]", pickle.ignore_string))
  |> pickle.parse("[20,72]", Point(0, 0), _)
  |> should.be_ok()
  |> should.equal(Point(20, 72))

  pickle.integer(fn(value, integer) { value + integer })
  |> pickle.then(pickle.string(";", pickle.ignore_string))
  |> pickle.then(pickle.integer(fn(value, integer) { value + integer }))
  |> pickle.then(pickle.string(";", pickle.ignore_string))
  |> pickle.then(pickle.integer(pickle.ignore_integer))
  |> pickle.parse("100;200;400", 0, _)
  |> should.be_ok()
  |> should.equal(300)
}

pub fn float_test() {
  pickle.float(fn(_, float) { float })
  |> pickle.parse("not_a_float", 0.0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    Pattern("^[0-9.]$"),
    "n",
    ParserPosition(0, 0),
  ))

  pickle.string("abc", pickle.ignore_string)
  |> pickle.then(pickle.float(fn(_, float) { float }))
  |> pickle.parse("abc-", 0.0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(Pattern("^[0-9.]$"), ParserPosition(0, 4)))

  pickle.string("abd", pickle.ignore_string)
  |> pickle.then(pickle.float(fn(_, float) { float }))
  |> pickle.parse("abc2000.0", 0.0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Literal("abd"), "abc", ParserPosition(0, 2)))

  pickle.float(fn(_, float) { float })
  |> pickle.parse("", 0.0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(Pattern("^[0-9.]$"), ParserPosition(0, 0)))

  pickle.float(fn(_, float) { float })
  |> pickle.parse("250.0", 0.0, _)
  |> should.be_ok()
  |> should.equal(250.0)

  pickle.float(fn(_, float) { float })
  |> pickle.parse("+20.4", 0.0, _)
  |> should.be_ok()
  |> should.equal(20.4)

  pickle.float(fn(_, float) { float })
  |> pickle.parse("-75.5", 0.0, _)
  |> should.be_ok()
  |> should.equal(-75.5)

  pickle.float(fn(_, float) { float })
  |> pickle.parse(".75", 0.0, _)
  |> should.be_ok()
  |> should.equal(0.75)

  pickle.float(fn(_, float) { float })
  |> pickle.parse("-.5", 0.0, _)
  |> should.be_ok()
  |> should.equal(-0.5)

  pickle.float(fn(_, float) { float })
  |> pickle.parse("5005.25abc", 0.0, _)
  |> should.be_ok()
  |> should.equal(5005.25)

  pickle.float(fn(_, float) { float })
  |> pickle.parse("25.5.1", 0.0, _)
  |> should.be_ok()
  |> should.equal(25.5)

  pickle.string("[", pickle.ignore_string)
  |> pickle.then(pickle.float(fn(value, float) { Point(..value, x: float) }))
  |> pickle.then(pickle.string(",", pickle.ignore_string))
  |> pickle.then(pickle.float(fn(value, float) { Point(..value, y: float) }))
  |> pickle.then(pickle.string("]", pickle.ignore_string))
  |> pickle.parse("[20.0,72.4]", Point(0.0, 0.0), _)
  |> should.be_ok()
  |> should.equal(Point(20.0, 72.4))

  pickle.float(fn(value, float) { value +. float })
  |> pickle.then(pickle.string(";", pickle.ignore_string))
  |> pickle.then(pickle.float(fn(value, float) { value +. float }))
  |> pickle.then(pickle.string(";", pickle.ignore_string))
  |> pickle.then(pickle.float(pickle.ignore_float))
  |> pickle.parse("100.5;200.5;400.0", 0.0, _)
  |> should.be_ok()
  |> should.equal(301.0)
}

pub fn until_test() {
  pickle.until("=", fn(value, string) { value <> string })
  |> pickle.parse("let test value;", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(Literal("="), ParserPosition(0, 15)))

  pickle.until("=", fn(value, string) { value <> string })
  |> pickle.parse("let test = \"value\";", "", _)
  |> should.be_ok()
  |> should.equal("let test ")

  pickle.until("EQUALS", fn(value, string) { value <> string })
  |> pickle.parse("var test EQUALS something", "", _)
  |> should.be_ok()
  |> should.equal("var test ")

  pickle.many(
    "",
    pickle.until("=", fn(value, string) { value <> string })
      |> pickle.then(pickle.string("=", pickle.ignore_string)),
    fn(value, string) { [string, ..value] },
  )
  |> pickle.parse("let test = \"value\";\nlet test2 = \"value2\";", [], _)
  |> should.be_ok()
  |> should.equal([" \"value\";\nlet test2 ", "let test "])
}

pub fn skip_until_test() {
  pickle.skip_until("=")
  |> pickle.parse("let test value;", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(Literal("="), ParserPosition(0, 15)))

  pickle.skip_until("=")
  |> pickle.then(pickle.until(";", fn(value, string) { value <> string }))
  |> pickle.parse("let test = \"value\";", "", _)
  |> should.be_ok()
  |> should.equal("= \"value\"")

  pickle.skip_until("EQUALS")
  |> pickle.then(pickle.until(" ", fn(value, string) { value <> string }))
  |> pickle.parse("var test EQUALS something", "", _)
  |> should.be_ok()
  |> should.equal("EQUALS")
}

pub fn whitespace_test() {
  pickle.string("aa", fn(value, string) { value <> string })
  |> pickle.then(pickle.whitespace(fn(value, string) { value <> string }))
  |> pickle.parse("ab\t \n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Literal("aa"), "ab", ParserPosition(0, 1)))

  pickle.whitespace(fn(value, string) { value <> string })
  |> pickle.parse("\t \n", "", _)
  |> should.be_ok()
  |> should.equal("\t \n")

  pickle.whitespace(fn(value, string) { value <> string })
  |> pickle.parse("\t \nabc", "", _)
  |> should.be_ok()
  |> should.equal("\t \n")

  pickle.whitespace(fn(value, string) { value <> string })
  |> pickle.parse("not_whitespace\t \n", "", _)
  |> should.be_ok()
  |> should.equal("")
}

pub fn skip_whitespace_test() {
  pickle.string("aa", fn(value, string) { value <> string })
  |> pickle.then(pickle.skip_whitespace())
  |> pickle.parse("ab\t \n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Literal("aa"), "ab", ParserPosition(0, 1)))

  pickle.string("something", fn(value, string) { value <> string })
  |> pickle.then(pickle.skip_whitespace())
  |> pickle.parse("something\t \n abc", "", _)
  |> should.be_ok()
  |> should.equal("something")

  pickle.skip_whitespace()
  |> pickle.parse("not_whitespace\t \n", "", _)
  |> should.be_ok()
  |> should.equal("")
}

pub fn one_of_test() {
  pickle.one_of([
    pickle.string("abc", fn(value, string) { value <> string }),
    pickle.string("abd", fn(value, string) { value <> string }),
  ])
  |> pickle.parse("ade", "", _)
  |> should.be_error()
  |> should.equal(
    OneOfError([
      UnexpectedToken(Literal("abd"), "ad", ParserPosition(0, 1)),
      UnexpectedToken(Literal("abc"), "ad", ParserPosition(0, 1)),
    ]),
  )

  pickle.string("123", fn(value, string) { value <> string })
  |> pickle.then(
    pickle.one_of([
      pickle.string("abc", fn(value, string) { value <> string }),
      pickle.string("abd", fn(value, string) { value <> string }),
    ]),
  )
  |> pickle.parse("abc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Literal("123"), "a", ParserPosition(0, 0)))

  pickle.one_of([
    pickle.string("abc", fn(value, string) { value <> string }),
    pickle.string("abd", fn(value, string) { value <> string }),
  ])
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal("abc")

  pickle.one_of([
    pickle.string("abc", fn(value, string) { value <> string }),
    pickle.string("abd", fn(value, string) { value <> string }),
  ])
  |> pickle.parse("abd", "", _)
  |> should.be_ok()
  |> should.equal("abd")

  pickle.one_of([])
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal("")
}

pub fn return_test() {
  pickle.string("abd", fn(value, string) { [string, ..value] })
  |> pickle.then(pickle.return(10))
  |> pickle.parse("abc", [], _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Literal("abd"), "abc", ParserPosition(0, 2)))

  pickle.string("abc", fn(value, string) { [string, ..value] })
  |> pickle.then(pickle.return(20))
  |> pickle.parse("abc", [], _)
  |> should.be_ok()
  |> should.equal(20)
}

pub fn eof_test() {
  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.eof())
  |> pickle.parse("abcd", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Eof, "d", ParserPosition(0, 3)))

  pickle.string("ab\nd", fn(value, string) { value <> string })
  |> pickle.then(pickle.eof())
  |> pickle.parse("ab\nc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    Literal("ab\nd"),
    "ab\nc",
    ParserPosition(1, 0),
  ))

  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.eof())
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal("abc")
}

type Point(a) {
  Point(x: a, y: a)
}
