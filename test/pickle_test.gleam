import gleam/int
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import pickle.{
  type ParserPosition, AsciiLetter, BinaryDigit, CustomError, DecimalDigit,
  DecimalDigitOrPoint, Eof, Eol, GuardError, HexadecimalDigit,
  LowercaseAsciiLetter, NonEof, NotError, OctalDigit, OneOfError, ParserPosition,
  String, UnexpectedEof, UnexpectedToken, Until1Error, UppercaseAsciiLetter,
  Whitespace,
}
import prelude.{because}

pub fn main() {
  gleeunit.main()
}

pub fn do_test() {
  pickle.string("(", string.append)
  |> pickle.then(
    pickle.do(
      Point(0, 0),
      pickle.integer(fn(point, x) { Point(..point, x: x) })
        |> pickle.then(pickle.string("|", pickle.drop))
        |> pickle.then(pickle.integer(fn(point, y) { Point(..point, y: y) }))
        |> pickle.then(
          pickle.map(fn(point: Point(Int)) {
            int.to_string(point.x) <> ";" <> int.to_string(point.y)
          }),
        ),
      fn(value, point_string) { value <> point_string },
    ),
  )
  |> pickle.then(pickle.string(")", string.append))
  |> pickle.parse("[2|-5]", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("("), "[", ParserPosition(0, 0)))
  |> because("a prior parser failed")

  pickle.string("(", string.append)
  |> pickle.then(
    pickle.do(
      Point(0, 0),
      pickle.integer(fn(point, x) { Point(..point, x: x) })
        |> pickle.then(pickle.string(",", pickle.drop))
        |> pickle.then(pickle.integer(fn(point, y) { Point(..point, y: y) }))
        |> pickle.then(
          pickle.map(fn(point: Point(Int)) {
            int.to_string(point.x) <> ";" <> int.to_string(point.y)
          }),
        ),
      fn(value, point_string) { value <> point_string },
    ),
  )
  |> pickle.then(pickle.string(")", string.append))
  |> pickle.parse("(510)", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String(","), ")", ParserPosition(0, 4)))
  |> because("the parser did fail")

  pickle.string("[", string.append)
  |> pickle.then(
    pickle.do(
      Point(0, 0),
      pickle.integer(fn(point, x) { Point(..point, x: x) })
        |> pickle.then(pickle.string(",", pickle.drop))
        |> pickle.then(pickle.integer(fn(point, y) { Point(..point, y: y) }))
        |> pickle.then(
          pickle.map(fn(point: Point(Int)) {
            int.to_string(point.x) <> ";" <> int.to_string(point.y)
          }),
        ),
      fn(value, point_string) { value <> point_string },
    ),
  )
  |> pickle.then(pickle.string("]", string.append))
  |> pickle.parse("[5,10]", "", _)
  |> should.be_ok()
  |> should.equal("[5;10]")
  |> because("the parser did not fail")
}

pub fn guard_test() {
  let error_message = "expected value to equal \"123\""

  pickle.string("abc", string.append)
  |> pickle.then(pickle.guard(fn(value) { value == "123" }, error_message))
  |> pickle.parse("abc", "", _)
  |> should.be_error()
  |> should.equal(GuardError(error_message, ParserPosition(0, 3)))
  |> because("abc doesn't equal 123")

  pickle.string("abc", string.append)
  |> pickle.then(pickle.guard(fn(value) { value == "123" }, "error message"))
  |> pickle.parse("abd", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abc"), "abd", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.string("abc", string.append)
  |> pickle.then(pickle.guard(fn(value) { value == "abc" }, "error message"))
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal("abc")
  |> because("the validation succeeded")
}

pub fn map_test() {
  pickle.string("abc", string.append)
  |> pickle.then(pickle.map(fn(value) { string.length(value) }))
  |> pickle.parse("a23", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abc"), "a2", ParserPosition(0, 1)))
  |> because("a prior parser failed")

  pickle.string("abc", string.append)
  |> pickle.then(pickle.map(fn(value) { string.length(value) }))
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal(3)
  |> because("the parser did not fail")
}

pub fn map_error_test() {
  pickle.string("abc", string.append)
  |> pickle.map_error(fn(failure) {
    case failure {
      UnexpectedToken(String(token), _, pos) -> Something(token, pos)
      _ -> Whatever
    }
  })
  |> pickle.then(pickle.eof())
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal("abc")
  |> because("the parser did not fail")

  pickle.string("abc", string.append)
  |> pickle.map_error(fn(failure) {
    case failure {
      UnexpectedToken(String(token), _, pos) -> Something(token, pos)
      _ -> Whatever
    }
  })
  |> pickle.then(pickle.eof())
  |> pickle.parse("a23", "", _)
  |> should.be_error()
  |> should.equal(CustomError(Something("abc", ParserPosition(0, 1))))
  |> because("the parser error value was mapped")
}

pub fn string_test() {
  pickle.string("123", string.append)
  |> pickle.then(pickle.string("abc", string.append))
  |> pickle.parse("abc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("123"), "a", ParserPosition(0, 0)))
  |> because("a doesn't equal 123")

  pickle.string("a\nb", string.append)
  |> pickle.parse("a\nc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("a\nb"), "a\nc", ParserPosition(1, 0)))
  |> because("a\nc doesn't equal a\nb")

  pickle.string("abc", string.append)
  |> pickle.parse("", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(String("abc"), ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.string("input", string.append)
  |> pickle.parse("input", "", _)
  |> should.be_ok()
  |> should.equal("input")
  |> because("the parser did not fail")
}

pub fn any_test() {
  pickle.string("test", string.append)
  |> pickle.then(pickle.any(string.append))
  |> pickle.parse("tesd", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("test"), "tesd", ParserPosition(0, 3)))
  |> because("a prior parser failed")

  pickle.any(string.append)
  |> pickle.parse("", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(NonEof, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.any(string.append)
  |> pickle.then(pickle.any(string.append))
  |> pickle.parse("ab", "", _)
  |> should.be_ok()
  |> should.equal("ab")
  |> because("two tokens could be consumed")
}

pub fn ascii_letter_test() {
  pickle.ascii_letter(string.append)
  |> pickle.parse("", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(AsciiLetter, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.ascii_letter(string.append)
  |> pickle.then(pickle.ascii_letter(string.append))
  |> pickle.parse("a2", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(AsciiLetter, "2", ParserPosition(0, 1)))
  |> because("2 is not an ASCII letter")

  pickle.ascii_letter(string.append)
  |> pickle.then(pickle.ascii_letter(string.append))
  |> pickle.parse("Aj", "", _)
  |> should.be_ok()
  |> should.equal("Aj")
  |> because("A and j are ASCII letters")
}

pub fn lowercase_ascii_letter_test() {
  pickle.lowercase_ascii_letter(string.append)
  |> pickle.parse("", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(LowercaseAsciiLetter, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.lowercase_ascii_letter(string.append)
  |> pickle.then(pickle.lowercase_ascii_letter(string.append))
  |> pickle.parse("aJ", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    LowercaseAsciiLetter,
    "J",
    ParserPosition(0, 1),
  ))
  |> because("J is not a lowercase ASCII letter")

  pickle.lowercase_ascii_letter(string.append)
  |> pickle.then(pickle.lowercase_ascii_letter(string.append))
  |> pickle.parse("aj", "", _)
  |> should.be_ok()
  |> should.equal("aj")
  |> because("a and j are lowercase ASCII letters")
}

pub fn uppercase_ascii_letter_test() {
  pickle.uppercase_ascii_letter(string.append)
  |> pickle.parse("", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(UppercaseAsciiLetter, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.uppercase_ascii_letter(string.append)
  |> pickle.then(pickle.uppercase_ascii_letter(string.append))
  |> pickle.parse("Aj", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    UppercaseAsciiLetter,
    "j",
    ParserPosition(0, 1),
  ))
  |> because("j is not an uppercase ASCII letter")

  pickle.uppercase_ascii_letter(string.append)
  |> pickle.then(pickle.uppercase_ascii_letter(string.append))
  |> pickle.parse("AJ", "", _)
  |> should.be_ok()
  |> should.equal("AJ")
  |> because("A and J are uppercase ASCII letters")
}

pub fn optional_test() {
  pickle.optional(pickle.string("(", pickle.drop))
  |> pickle.then(pickle.string("abc", string.append))
  |> pickle.then(pickle.optional(pickle.string("123", string.append)))
  |> pickle.parse("(abd123", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abc"), "abd", ParserPosition(0, 3)))
  |> because("a prior parser failed")

  pickle.optional(pickle.string("(", pickle.drop))
  |> pickle.then(pickle.string("value", string.append))
  |> pickle.then(pickle.optional(pickle.string(")", pickle.drop)))
  |> pickle.parse("(value)", "", _)
  |> should.be_ok()
  |> should.equal("value")
  |> because("no non-optional parser failed")

  pickle.optional(pickle.string("(", pickle.drop))
  |> pickle.then(pickle.string("value", string.append))
  |> pickle.then(pickle.optional(pickle.string(")", pickle.drop)))
  |> pickle.parse("value)", "", _)
  |> should.be_ok()
  |> should.equal("value")
  |> because("no non-optional parser failed")
}

pub fn many_test() {
  pickle.string("ab", list.prepend)
  |> pickle.then(pickle.many(
    "",
    pickle.string("a", string.append),
    list.prepend,
  ))
  |> pickle.parse("aaa", [], _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("ab"), "aa", ParserPosition(0, 1)))
  |> because("a prior parser failed")

  pickle.many("", pickle.string("a", string.append), list.prepend)
  |> pickle.parse("aaab", [], _)
  |> should.be_ok()
  |> should.equal(["a", "a", "a"])
  |> because("the given parser could be run three times without failing")

  pickle.many("", pickle.string("aa", string.append), list.prepend)
  |> pickle.then(pickle.string("ab", list.prepend))
  |> pickle.parse("abab", [], _)
  |> should.be_ok()
  |> should.equal(["ab"])
  |> because("the given parser could not be run without failing")
}

pub fn many1_test() {
  pickle.string("ab", list.prepend)
  |> pickle.then(pickle.many1(
    "",
    pickle.string("a", string.append),
    list.prepend,
  ))
  |> pickle.parse("aaa", [], _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("ab"), "aa", ParserPosition(0, 1)))
  |> because("a prior parser failed")

  pickle.many1("", pickle.string("aa", string.append), list.prepend)
  |> pickle.then(pickle.string("ab", list.prepend))
  |> pickle.parse("abab", [], _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("aa"), "ab", ParserPosition(0, 1)))
  |> because("the given parser failed at its first invocation")

  pickle.many1("", pickle.string("aa", string.append), list.prepend)
  |> pickle.parse("aaaaab", [], _)
  |> should.be_ok()
  |> should.equal(["aa", "aa"])
  |> because("the given parser could be run twice without failing")

  pickle.many1("", pickle.string("a", string.append), list.prepend)
  |> pickle.parse("aaab", [], _)
  |> should.be_ok()
  |> should.equal(["a", "a", "a"])
  |> because("the given parser could be run three times without failing")
}

pub fn times_test() {
  pickle.any(string.append)
  |> pickle.then(
    pickle.string("test", string.append)
    |> pickle.times(3),
  )
  |> pickle.then(pickle.string("something", string.append))
  |> pickle.parse("", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(NonEof, ParserPosition(0, 0)))
  |> because("a prior parser failed")

  pickle.string("test", string.append)
  |> pickle.times(3)
  |> pickle.then(pickle.string("something", string.append))
  |> pickle.parse("testtest", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(String("test"), ParserPosition(0, 8)))
  |> because("the given parser could only succeed twice")

  pickle.string("someone", string.append)
  |> pickle.times(0)
  |> pickle.then(pickle.string("something", string.append))
  |> pickle.parse("someone", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    String("something"),
    "someo",
    ParserPosition(0, 4),
  ))
  |> because("the given parser did not run once")

  pickle.string("someone", string.append)
  |> pickle.times(-1)
  |> pickle.then(pickle.string("something", string.append))
  |> pickle.parse("someone", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    String("something"),
    "someo",
    ParserPosition(0, 4),
  ))
  |> because("the given parser did not run once")

  pickle.string("test", string.append)
  |> pickle.times(3)
  |> pickle.then(pickle.string("something", pickle.drop))
  |> pickle.parse("testtesttestsomething", "", _)
  |> should.be_ok()
  |> should.equal("testtesttest")
  |> because("the given parser could succeed three times")

  pickle.string("test", string.append)
  |> pickle.times(1)
  |> pickle.then(pickle.string("something", pickle.drop))
  |> pickle.parse("testsomething", "", _)
  |> should.be_ok()
  |> should.equal("test")
  |> because("the given parser could succeed once")
}

pub fn digit_test() {
  pickle.digit(fn(value, digit) { value + digit })
  |> pickle.then(pickle.digit(fn(value, digit) { value + digit }))
  |> pickle.parse("1b", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(DecimalDigit, "b", ParserPosition(0, 1)))
  |> because("the second token is not a decimal digit")

  pickle.digit(fn(value, integer) { value + integer })
  |> pickle.parse("C", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(DecimalDigit, "C", ParserPosition(0, 0)))
  |> because("the provided input is not a decimal digit")

  pickle.string("ab\nd", pickle.drop)
  |> pickle.then(pickle.digit(fn(value, integer) { value + integer }))
  |> pickle.parse("ab\nc110", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    String("ab\nd"),
    "ab\nc",
    ParserPosition(1, 0),
  ))
  |> because("a prior parser failed")

  pickle.digit(fn(value, integer) { value + integer })
  |> pickle.parse("", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigit, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.digit(fn(value, integer) { value + integer })
  |> pickle.then(pickle.digit(fn(value, digit) { value + digit }))
  |> pickle.parse("12", 0, _)
  |> should.be_ok()
  |> should.equal(3)
  |> because("the parser could consume two decimal digits")
}

pub fn binary_digit_test() {
  pickle.binary_digit(fn(value, digit) { value + digit })
  |> pickle.then(pickle.binary_digit(fn(value, digit) { value + digit }))
  |> pickle.parse("1a", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(BinaryDigit, "a", ParserPosition(0, 1)))
  |> because("the second token is not a binary digit")

  pickle.binary_digit(fn(value, integer) { value + integer })
  |> pickle.parse("2", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(BinaryDigit, "2", ParserPosition(0, 0)))
  |> because("the provided input is not a binary digit")

  pickle.string("ab\nd", pickle.drop)
  |> pickle.then(pickle.binary_digit(fn(value, integer) { value + integer }))
  |> pickle.parse("ab\nc110", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    String("ab\nd"),
    "ab\nc",
    ParserPosition(1, 0),
  ))
  |> because("a prior parser failed")

  pickle.binary_digit(fn(value, integer) { value + integer })
  |> pickle.parse("", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(BinaryDigit, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.binary_digit(fn(value, integer) { value + integer })
  |> pickle.then(pickle.binary_digit(fn(value, digit) { value + digit }))
  |> pickle.parse("01", 0, _)
  |> should.be_ok()
  |> should.equal(1)
  |> because("the parser could consume two binary digits")
}

pub fn hexadecimal_digit_test() {
  pickle.hexadecimal_digit(fn(value, digit) { value + digit })
  |> pickle.then(pickle.hexadecimal_digit(fn(value, digit) { value + digit }))
  |> pickle.parse("1g", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(HexadecimalDigit, "g", ParserPosition(0, 1)))
  |> because("the second token is not a hexadecimal digit")

  pickle.hexadecimal_digit(fn(value, integer) { value + integer })
  |> pickle.parse("h", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(HexadecimalDigit, "h", ParserPosition(0, 0)))
  |> because("the provided input is not a hexadecimal digit")

  pickle.string("ab\nd", pickle.drop)
  |> pickle.then(
    pickle.hexadecimal_digit(fn(value, integer) { value + integer }),
  )
  |> pickle.parse("ab\nc110", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    String("ab\nd"),
    "ab\nc",
    ParserPosition(1, 0),
  ))
  |> because("a prior parser failed")

  pickle.hexadecimal_digit(fn(value, integer) { value + integer })
  |> pickle.parse("", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(HexadecimalDigit, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.hexadecimal_digit(fn(value, integer) { value + integer })
  |> pickle.then(pickle.hexadecimal_digit(fn(value, digit) { value + digit }))
  |> pickle.parse("C8", 0, _)
  |> should.be_ok()
  |> should.equal(20)
  |> because("the parser could consume two hexadecimal digits")
}

pub fn octal_digit_test() {
  pickle.octal_digit(fn(value, digit) { value + digit })
  |> pickle.then(pickle.octal_digit(fn(value, digit) { value + digit }))
  |> pickle.parse("18", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(OctalDigit, "8", ParserPosition(0, 1)))
  |> because("the second token is not an octal digit")

  pickle.octal_digit(fn(value, integer) { value + integer })
  |> pickle.parse("9", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(OctalDigit, "9", ParserPosition(0, 0)))
  |> because("the provided input is not an octal digit")

  pickle.string("ab\nd", pickle.drop)
  |> pickle.then(pickle.octal_digit(fn(value, integer) { value + integer }))
  |> pickle.parse("ab\nc110", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    String("ab\nd"),
    "ab\nc",
    ParserPosition(1, 0),
  ))
  |> because("a prior parser failed")

  pickle.octal_digit(fn(value, integer) { value + integer })
  |> pickle.parse("", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(OctalDigit, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.octal_digit(fn(value, integer) { value + integer })
  |> pickle.then(pickle.octal_digit(fn(value, digit) { value + digit }))
  |> pickle.parse("27", 0, _)
  |> should.be_ok()
  |> should.equal(9)
  |> because("the parser could consume two octal digits")
}

pub fn integer_test() {
  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("not_an_integer", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(DecimalDigit, "n", ParserPosition(0, 0)))
  |> because("the provided input is not an integer")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("fefefe", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(DecimalDigit, "f", ParserPosition(0, 0)))
  |> because("the provided input is a hexadecimal integer")

  pickle.string("abd", pickle.drop)
  |> pickle.then(pickle.integer(fn(_, integer) { integer }))
  |> pickle.parse("abc110", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abd"), "abc", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigit, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("-", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigit, ParserPosition(0, 1)))
  |> because("no input was left to parse")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("+", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigit, ParserPosition(0, 1)))
  |> because("no input was left to parse")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("+f", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(DecimalDigit, "f", ParserPosition(0, 1)))
  |> because("the provided positive decimal integer is invalid")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("-f", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(DecimalDigit, "f", ParserPosition(0, 1)))
  |> because("the provided negative decimal integer is invalid")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("110", 0, _)
  |> should.be_ok()
  |> should.equal(110)
  |> because("the parser was given a valid unsigned decimal integer")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("+10", 0, _)
  |> should.be_ok()
  |> should.equal(10)
  |> because("the parser was given a valid positive decimal integer")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("-101", 0, _)
  |> should.be_ok()
  |> should.equal(-101)
  |> because("the parser was given a valid negative decimal integer")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("10abc", 0, _)
  |> should.be_ok()
  |> should.equal(10)
  |> because("the parser stopped consuming input after the decimal integer")

  pickle.string("[", pickle.drop)
  |> pickle.then(
    pickle.integer(fn(value, integer) { Point(..value, x: integer) }),
  )
  |> pickle.then(pickle.string(",", pickle.drop))
  |> pickle.then(
    pickle.integer(fn(value, integer) { Point(..value, y: integer) }),
  )
  |> pickle.then(pickle.string("]", pickle.drop))
  |> pickle.parse("[-5,10]", Point(0, 0), _)
  |> should.be_ok()
  |> should.equal(Point(-5, 10))
  |> because("the point could be parsed")

  pickle.integer(fn(value, integer) { value + integer })
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.integer(fn(value, integer) { value + integer }))
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.integer(pickle.drop))
  |> pickle.parse("100;-1000;11", 0, _)
  |> should.be_ok()
  |> should.equal(-900)
  |> because("the last decimal integer is not added to the sum")
}

pub fn binary_integer_test() {
  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("not_an_integer", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(BinaryDigit, "n", ParserPosition(0, 0)))
  |> because("the provided input is not an integer")

  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("25", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(BinaryDigit, "2", ParserPosition(0, 0)))
  |> because("the provided input is a decimal integer")

  pickle.string("abd", pickle.drop)
  |> pickle.then(pickle.binary_integer(fn(_, integer) { integer }))
  |> pickle.parse("abc110", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abd"), "abc", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(BinaryDigit, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("-", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(BinaryDigit, ParserPosition(0, 1)))
  |> because("no input was left to parse")

  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("+", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(BinaryDigit, ParserPosition(0, 1)))
  |> because("no input was left to parse")

  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("110", 0, _)
  |> should.be_ok()
  |> should.equal(6)
  |> because("the parser was given a valid unsigned binary integer")

  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("+10", 0, _)
  |> should.be_ok()
  |> should.equal(2)
  |> because("the parser was given a valid positive binary integer")

  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("-101", 0, _)
  |> should.be_ok()
  |> should.equal(-5)
  |> because("the parser was given a valid negative binary integer")

  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("10abc", 0, _)
  |> should.be_ok()
  |> should.equal(2)
  |> because("the parser stopped consuming input after the binary integer")

  pickle.string("[", pickle.drop)
  |> pickle.then(
    pickle.binary_integer(fn(value, integer) { Point(..value, x: integer) }),
  )
  |> pickle.then(pickle.string(",", pickle.drop))
  |> pickle.then(
    pickle.binary_integer(fn(value, integer) { Point(..value, y: integer) }),
  )
  |> pickle.then(pickle.string("]", pickle.drop))
  |> pickle.parse("[11,101]", Point(0, 0), _)
  |> should.be_ok()
  |> should.equal(Point(3, 5))
  |> because("the point could be parsed")

  pickle.binary_integer(fn(value, integer) { value + integer })
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.binary_integer(fn(value, integer) { value + integer }))
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.binary_integer(pickle.drop))
  |> pickle.parse("100;1000;11", 0, _)
  |> should.be_ok()
  |> should.equal(12)
  |> because("the last binary integer is not added to the sum")
}

pub fn hexadecimal_integer_test() {
  pickle.hexadecimal_integer(fn(_, integer) { integer })
  |> pickle.parse("not_an_integer", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(HexadecimalDigit, "n", ParserPosition(0, 0)))
  |> because("the provided input is not an integer")

  pickle.string("abd", pickle.drop)
  |> pickle.then(pickle.hexadecimal_integer(fn(_, integer) { integer }))
  |> pickle.parse("abc1ef", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abd"), "abc", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.hexadecimal_integer(fn(_, integer) { integer })
  |> pickle.parse("", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(HexadecimalDigit, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.hexadecimal_integer(fn(_, integer) { integer })
  |> pickle.parse("-", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(HexadecimalDigit, ParserPosition(0, 1)))
  |> because("no input was left to parse")

  pickle.hexadecimal_integer(fn(_, integer) { integer })
  |> pickle.parse("+", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(HexadecimalDigit, ParserPosition(0, 1)))
  |> because("no input was left to parse")

  pickle.hexadecimal_integer(fn(_, integer) { integer })
  |> pickle.parse("1F", 0, _)
  |> should.be_ok()
  |> should.equal(31)
  |> because("the parser was given a valid unsigned hexadecimal integer")

  pickle.hexadecimal_integer(fn(_, integer) { integer })
  |> pickle.parse("+B", 0, _)
  |> should.be_ok()
  |> should.equal(11)
  |> because("the parser was given a valid positive hexadecimal integer")

  pickle.hexadecimal_integer(fn(_, integer) { integer })
  |> pickle.parse("-3C", 0, _)
  |> should.be_ok()
  |> should.equal(-60)
  |> because("the parser was given a valid negative hexadecimal integer")

  pickle.hexadecimal_integer(fn(_, integer) { integer })
  |> pickle.parse("FEsomething else", 0, _)
  |> should.be_ok()
  |> should.equal(254)
  |> because("the parser stopped consuming input after the hexadecimal integer")

  pickle.string("[", pickle.drop)
  |> pickle.then(
    pickle.hexadecimal_integer(fn(value, integer) { Point(..value, x: integer) }),
  )
  |> pickle.then(pickle.string(",", pickle.drop))
  |> pickle.then(
    pickle.hexadecimal_integer(fn(value, integer) { Point(..value, y: integer) }),
  )
  |> pickle.then(pickle.string("]", pickle.drop))
  |> pickle.parse("[c,1A]", Point(0, 0), _)
  |> should.be_ok()
  |> should.equal(Point(12, 26))
  |> because("the point could be parsed")

  pickle.hexadecimal_integer(fn(value, integer) { value + integer })
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(
    pickle.hexadecimal_integer(fn(value, integer) { value + integer }),
  )
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.hexadecimal_integer(pickle.drop))
  |> pickle.parse("1F;9e;-FFFeee", 0, _)
  |> should.be_ok()
  |> should.equal(189)
  |> because("the last hexadecimal integer is not added to the sum")
}

pub fn octal_integer_test() {
  pickle.octal_integer(fn(_, integer) { integer })
  |> pickle.parse("not_an_integer", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(OctalDigit, "n", ParserPosition(0, 0)))
  |> because("the provided input is not an integer")

  pickle.string("abd", pickle.drop)
  |> pickle.then(pickle.octal_integer(fn(_, integer) { integer }))
  |> pickle.parse("abc1ef", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abd"), "abc", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.octal_integer(fn(_, integer) { integer })
  |> pickle.parse("", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(OctalDigit, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.octal_integer(fn(_, integer) { integer })
  |> pickle.parse("-", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(OctalDigit, ParserPosition(0, 1)))
  |> because("no input was left to parse")

  pickle.octal_integer(fn(_, integer) { integer })
  |> pickle.parse("+", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(OctalDigit, ParserPosition(0, 1)))
  |> because("no input was left to parse")

  pickle.octal_integer(fn(_, integer) { integer })
  |> pickle.parse("12", 0, _)
  |> should.be_ok()
  |> should.equal(10)
  |> because("the parser was given a valid unsigned octal integer")

  pickle.octal_integer(fn(_, integer) { integer })
  |> pickle.parse("+23", 0, _)
  |> should.be_ok()
  |> should.equal(19)
  |> because("the parser was given a valid positive octal integer")

  pickle.octal_integer(fn(_, integer) { integer })
  |> pickle.parse("-37", 0, _)
  |> should.be_ok()
  |> should.equal(-31)
  |> because("the parser was given a valid negative octal integer")

  pickle.octal_integer(fn(_, integer) { integer })
  |> pickle.parse("11something else", 0, _)
  |> should.be_ok()
  |> should.equal(9)
  |> because("the parser stopped consuming input after the octal integer")

  pickle.string("[", pickle.drop)
  |> pickle.then(
    pickle.octal_integer(fn(value, integer) { Point(..value, x: integer) }),
  )
  |> pickle.then(pickle.string(",", pickle.drop))
  |> pickle.then(
    pickle.octal_integer(fn(value, integer) { Point(..value, y: integer) }),
  )
  |> pickle.then(pickle.string("]", pickle.drop))
  |> pickle.parse("[45,-11]", Point(0, 0), _)
  |> should.be_ok()
  |> should.equal(Point(37, -9))
  |> because("the point could be parsed")

  pickle.octal_integer(fn(value, integer) { value + integer })
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.octal_integer(fn(value, integer) { value + integer }))
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.octal_integer(pickle.drop))
  |> pickle.parse("-15;11;77", 0, _)
  |> should.be_ok()
  |> should.equal(-4)
  |> because("the last octal integer is not added to the sum")
}

pub fn float_test() {
  pickle.float(fn(_, float) { float })
  |> pickle.parse("not_a_float", 0.0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    DecimalDigitOrPoint,
    "n",
    ParserPosition(0, 0),
  ))
  |> because("the provided input is not a float")

  pickle.string("abc", pickle.drop)
  |> pickle.then(pickle.float(fn(_, float) { float }))
  |> pickle.parse("abc-", 0.0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigitOrPoint, ParserPosition(0, 4)))
  |> because("no input was left to parse")

  pickle.string("abc", pickle.drop)
  |> pickle.then(pickle.float(fn(_, float) { float }))
  |> pickle.parse("abc+", 0.0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigitOrPoint, ParserPosition(0, 4)))
  |> because("no input was left to parse")

  pickle.string("abd", pickle.drop)
  |> pickle.then(pickle.float(fn(_, float) { float }))
  |> pickle.parse("abc2000.0", 0.0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abd"), "abc", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.float(fn(_, float) { float })
  |> pickle.parse("", 0.0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigitOrPoint, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.float(fn(_, float) { float })
  |> pickle.parse("+", 0.0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigitOrPoint, ParserPosition(0, 1)))
  |> because("no input was left to parse")

  pickle.float(fn(_, float) { float })
  |> pickle.parse("-", 0.0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigitOrPoint, ParserPosition(0, 1)))
  |> because("no input was left to parse")

  pickle.float(fn(_, float) { float })
  |> pickle.parse("250.0", 0.0, _)
  |> should.be_ok()
  |> should.equal(250.0)
  |> because("the parser was given a valid float")

  pickle.float(fn(_, float) { float })
  |> pickle.parse("+20.4", 0.0, _)
  |> should.be_ok()
  |> should.equal(20.4)
  |> because("the parser was given a valid positive float")

  pickle.float(fn(_, float) { float })
  |> pickle.parse("-75.5", 0.0, _)
  |> should.be_ok()
  |> should.equal(-75.5)
  |> because("the parser was given a valid negative float")

  pickle.float(fn(_, float) { float })
  |> pickle.parse(".75", 0.0, _)
  |> should.be_ok()
  |> should.equal(0.75)
  |> because("the parser was given a valid float")

  pickle.float(fn(_, float) { float })
  |> pickle.parse("-.5", 0.0, _)
  |> should.be_ok()
  |> should.equal(-0.5)
  |> because("the parser was given a valid negative float")

  pickle.float(fn(_, float) { float })
  |> pickle.parse("5005.25abc", 0.0, _)
  |> should.be_ok()
  |> should.equal(5005.25)
  |> because("the parser stopped consuming input after the float")

  pickle.float(fn(_, float) { float })
  |> pickle.parse("25.5.1", 0.0, _)
  |> should.be_ok()
  |> should.equal(25.5)
  |> because("the parser stopped consuming input after the float")

  pickle.string("[", pickle.drop)
  |> pickle.then(pickle.float(fn(value, float) { Point(..value, x: float) }))
  |> pickle.then(pickle.string(",", pickle.drop))
  |> pickle.then(pickle.float(fn(value, float) { Point(..value, y: float) }))
  |> pickle.then(pickle.string("]", pickle.drop))
  |> pickle.parse("[20.0,72.4]", Point(0.0, 0.0), _)
  |> should.be_ok()
  |> should.equal(Point(20.0, 72.4))
  |> because("the point could be parsed")

  pickle.float(fn(value, float) { value +. float })
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.float(fn(value, float) { value +. float }))
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.float(pickle.drop))
  |> pickle.parse("100.5;200.5;400.0", 0.0, _)
  |> should.be_ok()
  |> should.equal(301.0)
  |> because("the last float is not added to the sum")
}

pub fn until_test() {
  pickle.until(
    "",
    pickle.any(string.append),
    pickle.string("=", pickle.drop),
    string.append,
  )
  |> pickle.parse("let test value;", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(String("="), ParserPosition(0, 15)))
  |> because("the terminator could not be found")

  pickle.until(
    "",
    pickle.string(";", string.append),
    pickle.eol(pickle.drop),
    string.append,
  )
  |> pickle.parse(";;;;;;,\n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String(";"), ",", ParserPosition(0, 6)))
  |> because(
    "the parser encountered an unexpected token before the terminator succeeded",
  )

  pickle.until("", pickle.any(string.append), pickle.eof(), string.append)
  |> pickle.parse("let test = \"value\";", "", _)
  |> should.be_ok()
  |> should.equal("let test = \"value\";")
  |> because("the terminator did succeed")

  pickle.until(
    "",
    pickle.any(string.append),
    pickle.string("EQUALS", pickle.drop),
    string.append,
  )
  |> pickle.parse("var test EQUALS something", "", _)
  |> should.be_ok()
  |> should.equal("var test ")
  |> because("the terminator did succeed")

  pickle.many(
    "",
    pickle.until(
      "",
      pickle.any(string.append),
      pickle.string("=", pickle.drop),
      string.append,
    )
      |> pickle.then(pickle.string("=", pickle.drop)),
    list.prepend,
  )
  |> pickle.parse("let test = \"value\";\nlet test2 = \"value2\";", [], _)
  |> should.be_ok()
  |> should.equal([" \"value\";\nlet test2 ", "let test "])
  |> because("the terminator did succeed twice")
}

pub fn until1_test() {
  pickle.until1(
    "",
    pickle.any(string.append),
    pickle.string("=", pickle.drop),
    string.append,
  )
  |> pickle.parse("let test value;", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(String("="), ParserPosition(0, 15)))
  |> because("the terminator could not be found")

  pickle.until1(
    "",
    pickle.string("test", string.append),
    pickle.string("t", pickle.drop),
    string.append,
  )
  |> pickle.parse("test", "", _)
  |> should.be_error()
  |> should.equal(Until1Error(ParserPosition(0, 0)))
  |> because("the terminator succeeded before the given parser could succeed")

  pickle.until1(
    "",
    pickle.string(";", string.append),
    pickle.eol(pickle.drop),
    string.append,
  )
  |> pickle.parse(";;;;;;,\n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String(";"), ",", ParserPosition(0, 6)))
  |> because(
    "the parser encountered an unexpected token before the terminator succeeded",
  )

  pickle.until1("", pickle.any(string.append), pickle.eof(), string.append)
  |> pickle.parse("let test = \"value\";", "", _)
  |> should.be_ok()
  |> should.equal("let test = \"value\";")
  |> because("the terminator did succeed")

  pickle.until1(
    "",
    pickle.any(string.append),
    pickle.string("EQUALS", pickle.drop),
    string.append,
  )
  |> pickle.parse("var test EQUALS something", "", _)
  |> should.be_ok()
  |> should.equal("var test ")
  |> because("the terminator did succeed")

  pickle.many(
    "",
    pickle.until1(
      "",
      pickle.any(string.append),
      pickle.string("=", pickle.drop),
      string.append,
    )
      |> pickle.then(pickle.string("=", pickle.drop)),
    list.prepend,
  )
  |> pickle.parse("let test = \"value\";\nlet test2 = \"value2\";", [], _)
  |> should.be_ok()
  |> should.equal([" \"value\";\nlet test2 ", "let test "])
  |> because("the terminator did succeed twice")
}

pub fn skip_until_test() {
  pickle.skip_until(pickle.string("=", pickle.drop))
  |> pickle.parse("let test value;", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(String("="), ParserPosition(0, 15)))
  |> because("the terminator did not succeed")

  pickle.skip_until(pickle.string("=", pickle.drop))
  |> pickle.then(pickle.until(
    "",
    pickle.any(string.append),
    pickle.string(";", pickle.drop),
    string.append,
  ))
  |> pickle.parse("let test = \"value\";", "", _)
  |> should.be_ok()
  |> should.equal("= \"value\"")
  |> because("the terminator did succeed")

  pickle.skip_until(pickle.string("EQUALS", pickle.drop))
  |> pickle.then(pickle.until(
    "",
    pickle.any(string.append),
    pickle.string(" ", pickle.drop),
    string.append,
  ))
  |> pickle.parse("var test EQUALS something", "", _)
  |> should.be_ok()
  |> should.equal("EQUALS")
  |> because("the terminator did succeed")
}

pub fn skip_until1_test() {
  pickle.skip_until1(pickle.string("=", pickle.drop))
  |> pickle.parse("let test value;", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(String("="), ParserPosition(0, 15)))
  |> because("the terminator did not succeed")

  pickle.skip_until1(pickle.eof())
  |> pickle.parse("", "", _)
  |> should.be_error()
  |> should.equal(Until1Error(ParserPosition(0, 0)))
  |> because("the terminator succeeded before the given parser could succeed")

  pickle.skip_until1(pickle.string("=", pickle.drop))
  |> pickle.then(pickle.until(
    "",
    pickle.any(string.append),
    pickle.string(";", pickle.drop),
    string.append,
  ))
  |> pickle.parse("let test = \"value\";", "", _)
  |> should.be_ok()
  |> should.equal("= \"value\"")
  |> because("the terminator did succeed")

  pickle.skip_until1(pickle.string("EQUALS", pickle.drop))
  |> pickle.then(pickle.until(
    "",
    pickle.any(string.append),
    pickle.string(" ", pickle.drop),
    string.append,
  ))
  |> pickle.parse("var test EQUALS something", "", _)
  |> should.be_ok()
  |> should.equal("EQUALS")
  |> because("the terminator did succeed")
}

pub fn whitespace_test() {
  pickle.string("aa", string.append)
  |> pickle.then(pickle.whitespace(string.append))
  |> pickle.parse("ab\t \n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("aa"), "ab", ParserPosition(0, 1)))
  |> because("a prior parser failed")

  pickle.whitespace(string.append)
  |> pickle.parse("\t \n", "", _)
  |> should.be_ok()
  |> should.equal("\t \n")
  |> because("the entire input consisted of whitespace")

  pickle.whitespace(string.append)
  |> pickle.parse("\t \nabc", "", _)
  |> should.be_ok()
  |> should.equal("\t \n")
  |> because("it consumed all whitespace until reaching non-whitespace tokens")

  pickle.whitespace(string.append)
  |> pickle.parse("not_whitespace\t \n", "", _)
  |> should.be_ok()
  |> should.equal("")
  |> because("the input didn't start with whitespace")
}

pub fn whitespace1_test() {
  pickle.string("aa", string.append)
  |> pickle.then(pickle.whitespace1(string.append))
  |> pickle.parse("ab\t \n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("aa"), "ab", ParserPosition(0, 1)))
  |> because("a prior parser failed")

  pickle.whitespace1(string.append)
  |> pickle.parse("not_whitespace\t \n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Whitespace, "n", ParserPosition(0, 0)))
  |> because("the given parser failed at its first invocation")

  pickle.whitespace1(string.append)
  |> pickle.parse("\t \n", "", _)
  |> should.be_ok()
  |> should.equal("\t \n")
  |> because("the entire input consisted of whitespace")

  pickle.whitespace1(string.append)
  |> pickle.parse("\t \nabc", "", _)
  |> should.be_ok()
  |> should.equal("\t \n")
  |> because("it consumed all whitespace until reaching non-whitespace tokens")
}

pub fn skip_whitespace_test() {
  pickle.string("aa", string.append)
  |> pickle.then(pickle.skip_whitespace())
  |> pickle.parse("ab\t \n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("aa"), "ab", ParserPosition(0, 1)))
  |> because("a prior parser failed")

  pickle.string("something", string.append)
  |> pickle.then(pickle.skip_whitespace())
  |> pickle.then(pickle.string("abc", string.append))
  |> pickle.parse("something\t \n abc", "", _)
  |> should.be_ok()
  |> should.equal("somethingabc")
  |> because("the whitespace in-between has been skipped")

  pickle.skip_whitespace()
  |> pickle.parse("not_whitespace\t \n", "", _)
  |> should.be_ok()
  |> should.equal("")
  |> because("the input didn't start with whitespace")
}

pub fn skip_whitespace1_test() {
  pickle.string("aa", string.append)
  |> pickle.then(pickle.skip_whitespace1())
  |> pickle.parse("ab\t \n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("aa"), "ab", ParserPosition(0, 1)))
  |> because("a prior parser failed")

  pickle.skip_whitespace1()
  |> pickle.parse("not_whitespace\t \n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Whitespace, "n", ParserPosition(0, 0)))
  |> because("the given parser failed at its first invocation")

  pickle.string("something", string.append)
  |> pickle.then(pickle.skip_whitespace1())
  |> pickle.then(pickle.string("abc", string.append))
  |> pickle.parse("something\t \n abc", "", _)
  |> should.be_ok()
  |> should.equal("somethingabc")
  |> because("the whitespace in-between has been skipped")
}

pub fn one_of_test() {
  pickle.one_of([
    pickle.string("abc", string.append),
    pickle.string("abd", string.append),
  ])
  |> pickle.parse("ade", "", _)
  |> should.be_error()
  |> should.equal(
    OneOfError([
      UnexpectedToken(String("abd"), "ad", ParserPosition(0, 1)),
      UnexpectedToken(String("abc"), "ad", ParserPosition(0, 1)),
    ]),
  )
  |> because("all given parsers failed")

  pickle.string("123", string.append)
  |> pickle.then(
    pickle.one_of([
      pickle.string("abc", string.append),
      pickle.string("abd", string.append),
    ]),
  )
  |> pickle.parse("abc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("123"), "a", ParserPosition(0, 0)))
  |> because("a prior parser failed")

  pickle.one_of([
    pickle.string("abc", string.append),
    pickle.string("abd", string.append),
  ])
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal("abc")
  |> because("the first given parser succeeded")

  pickle.one_of([
    pickle.string("abc", string.append),
    pickle.string("abd", string.append),
  ])
  |> pickle.parse("abd", "", _)
  |> should.be_ok()
  |> should.equal("abd")
  |> because("the second given parser succeeded")

  pickle.one_of([])
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal("")
  |> because("no parsers were given")
}

pub fn return_test() {
  pickle.string("abd", list.prepend)
  |> pickle.then(pickle.return(10))
  |> pickle.parse("abc", [], _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abd"), "abc", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.string("abc", list.prepend)
  |> pickle.then(pickle.return(20))
  |> pickle.parse("abc", [], _)
  |> should.be_ok()
  |> should.equal(20)
  |> because("the value has been overridden")
}

pub fn eof_test() {
  pickle.string("ab\nd", string.append)
  |> pickle.then(pickle.eof())
  |> pickle.parse("ab\nc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    String("ab\nd"),
    "ab\nc",
    ParserPosition(1, 0),
  ))
  |> because("a prior parser failed")

  pickle.string("abc", string.append)
  |> pickle.then(pickle.eof())
  |> pickle.parse("abcd", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Eof, "d", ParserPosition(0, 3)))
  |> because("there was input left to parse")

  pickle.string("abc", string.append)
  |> pickle.then(pickle.eof())
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal("abc")
  |> because("there was no input left to parse")
}

pub fn eol_test() {
  pickle.string("abc", pickle.drop)
  |> pickle.then(pickle.eol(pickle.drop))
  |> pickle.parse("abd\n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abc"), "abd", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.string("abc", pickle.drop)
  |> pickle.then(pickle.eol(pickle.drop))
  |> pickle.parse("abc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(Eol, ParserPosition(0, 3)))
  |> because("no end-of-line character could be found")

  pickle.string("abc", string.append)
  |> pickle.then(pickle.eol(pickle.drop))
  |> pickle.then(pickle.string("def", string.append))
  |> pickle.parse("abc\ndef", "", _)
  |> should.be_ok()
  |> should.equal("abcdef")
  |> because("an LF character could be found")

  pickle.string("abc", string.append)
  |> pickle.then(pickle.eol(pickle.drop))
  |> pickle.then(pickle.string("def", string.append))
  |> pickle.parse("abc\r\ndef", "", _)
  |> should.be_ok()
  |> should.equal("abcdef")
  |> because("a CRLF character could be found")
}

pub fn not_test() {
  pickle.string("abc", string.append)
  |> pickle.then(pickle.not(
    pickle.string("123", pickle.drop),
    DidNotExpectThisToSucceed,
  ))
  |> pickle.parse("abd123", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abc"), "abd", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.string("abc", string.append)
  |> pickle.then(pickle.not(
    pickle.string("123", pickle.drop),
    DidNotExpectThisToSucceed,
  ))
  |> pickle.parse("abc123", "", _)
  |> should.be_error()
  |> should.equal(NotError(DidNotExpectThisToSucceed, ParserPosition(0, 3)))
  |> because("123 could be parsed successfully")

  pickle.string("abc", string.append)
  |> pickle.then(pickle.not(
    pickle.string("123", pickle.drop),
    DidNotExpectThisToSucceed,
  ))
  |> pickle.parse("abcdef", "", _)
  |> should.be_ok()
  |> should.equal("abc")
  |> because("123 could not be parsed successfully")
}

pub fn lookahead_test() {
  pickle.string("124", pickle.drop)
  |> pickle.then(pickle.lookahead(pickle.string("abc", pickle.drop)))
  |> pickle.parse("123\nabc456", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("124"), "123", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.lookahead(pickle.string("abc", pickle.drop))
  |> pickle.parse("123\nabd456", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(String("abc"), ParserPosition(1, 6)))
  |> because("abc could not be found")

  pickle.lookahead(pickle.string("abc", pickle.drop))
  |> pickle.then(pickle.string("123\n", string.append))
  |> pickle.parse("123\nabc456", "", _)
  |> should.be_ok()
  |> should.equal("123\n")
  |> because("abc could be found")

  pickle.lookahead(pickle.eof())
  |> pickle.then(pickle.string("123", string.append))
  |> pickle.parse("123", "", _)
  |> should.be_ok()
  |> should.equal("123")
  |> because("looking ahead for an EOF always succeeds")
}

type Point(a) {
  Point(x: a, y: a)
}

type TestError {
  Something(token: String, pos: ParserPosition)
  DidNotExpectThisToSucceed
  Whatever
}
