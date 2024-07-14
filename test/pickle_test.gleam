import gleam/string
import gleeunit
import gleeunit/should
import pickle.{
  type ParserPosition, BinaryDigit, CustomError, DecimalDigit,
  DecimalDigitOrPoint, Eof, GuardError, HexadecimalDigit, LowercaseAsciiLetter,
  OctalDigit, OneOfError, ParserPosition, String, UnexpectedEof, UnexpectedToken,
}
import prelude.{because}

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
  |> because("abc doesn't equal 123")

  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.guard(fn(value) { value == "123" }, "error message"))
  |> pickle.parse("abd", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abc"), "abd", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.guard(fn(value) { value == "abc" }, "error message"))
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal("abc")
  |> because("the validation succeeded")
}

pub fn map_test() {
  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.map(fn(value) { string.length(value) }))
  |> pickle.parse("a23", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abc"), "a2", ParserPosition(0, 1)))
  |> because("a prior parser failed")

  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.map(fn(value) { string.length(value) }))
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal(3)
  |> because("the parser did not fail")
}

pub fn map_error_test() {
  pickle.string("abc", fn(value, string) { value <> string })
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

  pickle.string("abc", fn(value, string) { value <> string })
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
  pickle.string("123", fn(value, string) { value <> string })
  |> pickle.then(pickle.string("abc", fn(value, string) { value <> string }))
  |> pickle.parse("abc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("123"), "a", ParserPosition(0, 0)))
  |> because("a doesn't equal 123")

  pickle.string("a\nb", fn(value, string) { value <> string })
  |> pickle.parse("a\nc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("a\nb"), "a\nc", ParserPosition(1, 0)))
  |> because("a\nc doesn't equal a\nb")

  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.parse("", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(String("abc"), ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.string("input", fn(value, string) { value <> string })
  |> pickle.parse("input", "", _)
  |> should.be_ok()
  |> should.equal("input")
  |> because("the parser did not fail")
}

pub fn lowercase_ascii_letter_test() {
  pickle.lowercase_ascii_letter(fn(value, letter) { value <> letter })
  |> pickle.parse("", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(LowercaseAsciiLetter, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.lowercase_ascii_letter(fn(value, letter) { value <> letter })
  |> pickle.then(
    pickle.lowercase_ascii_letter(fn(value, letter) { value <> letter }),
  )
  |> pickle.parse("aJ", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    LowercaseAsciiLetter,
    "J",
    ParserPosition(0, 1),
  ))
  |> because("J is not a lowercase ASCII letter")

  pickle.lowercase_ascii_letter(fn(value, letter) { value <> letter })
  |> pickle.then(
    pickle.lowercase_ascii_letter(fn(value, letter) { value <> letter }),
  )
  |> pickle.parse("aj", "", _)
  |> should.be_ok()
  |> should.equal("aj")
  |> because("a and j are lowercase ASCII letters")
}

pub fn optional_test() {
  pickle.optional(pickle.string("(", pickle.drop))
  |> pickle.then(pickle.string("abc", fn(value, string) { value <> string }))
  |> pickle.then(
    pickle.optional(pickle.string("123", fn(value, string) { value <> string })),
  )
  |> pickle.parse("(abd123", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abc"), "abd", ParserPosition(0, 3)))
  |> because("a prior parser failed")

  pickle.optional(pickle.string("(", pickle.drop))
  |> pickle.then(pickle.string("value", fn(value, string) { value <> string }))
  |> pickle.then(pickle.optional(pickle.string(")", pickle.drop)))
  |> pickle.parse("(value)", "", _)
  |> should.be_ok()
  |> should.equal("value")
  |> because("no non-optional parser failed")

  pickle.optional(pickle.string("(", pickle.drop))
  |> pickle.then(pickle.string("value", fn(value, string) { value <> string }))
  |> pickle.then(pickle.optional(pickle.string(")", pickle.drop)))
  |> pickle.parse("value)", "", _)
  |> should.be_ok()
  |> should.equal("value")
  |> because("no non-optional parser failed")
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
  |> should.equal(UnexpectedToken(String("ab"), "aa", ParserPosition(0, 1)))
  |> because("a prior parser failed")

  pickle.many(
    "",
    pickle.string("a", fn(value, string) { value <> string }),
    fn(value, string) { [string, ..value] },
  )
  |> pickle.parse("aaab", [], _)
  |> should.be_ok()
  |> should.equal(["a", "a", "a"])
  |> because("the given parser could be run three times without failing")

  pickle.many(
    "",
    pickle.string("aa", fn(value, string) { value <> string }),
    fn(value, string) { [string, ..value] },
  )
  |> pickle.then(pickle.string("ab", fn(value, string) { [string, ..value] }))
  |> pickle.parse("abab", [], _)
  |> should.be_ok()
  |> should.equal(["ab"])
  |> because("the given parser could not be run without failing")
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
  |> pickle.parse("0b", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(BinaryDigit, ParserPosition(0, 2)))
  |> because("no input was left to parse")

  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("0B", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(BinaryDigit, ParserPosition(0, 2)))
  |> because("no input was left to parse")

  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("0b2", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(BinaryDigit, "2", ParserPosition(0, 2)))
  |> because("the provided prefixed binary integer is invalid")

  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("0b110", 0, _)
  |> should.be_ok()
  |> should.equal(6)
  |> because("the parser was given a valid prefixed binary integer")

  pickle.binary_integer(fn(_, integer) { integer })
  |> pickle.parse("110", 0, _)
  |> should.be_ok()
  |> should.equal(6)
  |> because("the parser was given a valid unprefixed binary integer")

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
  |> pickle.parse("0b10abc", 0, _)
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
  |> pickle.parse("[0b11,101]", Point(0, 0), _)
  |> should.be_ok()
  |> should.equal(Point(3, 5))
  |> because("the point could be parsed")

  pickle.binary_integer(fn(value, integer) { value + integer })
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.binary_integer(fn(value, integer) { value + integer }))
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.binary_integer(pickle.drop))
  |> pickle.parse("100;0b1000;11", 0, _)
  |> should.be_ok()
  |> should.equal(12)
  |> because("the last binary integer is not added to the sum")
}

pub fn decimal_integer_test() {
  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("not_an_integer", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(DecimalDigit, "n", ParserPosition(0, 0)))
  |> because("the provided input is not an integer")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("fefefe", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(DecimalDigit, "f", ParserPosition(0, 0)))
  |> because("the provided input is a hexadecimal integer")

  pickle.string("abd", pickle.drop)
  |> pickle.then(pickle.decimal_integer(fn(_, integer) { integer }))
  |> pickle.parse("abc110", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abd"), "abc", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigit, ParserPosition(0, 0)))
  |> because("no input was left to parse")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("-", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigit, ParserPosition(0, 1)))
  |> because("no input was left to parse")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("+", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigit, ParserPosition(0, 1)))
  |> because("no input was left to parse")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("+f", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(DecimalDigit, "f", ParserPosition(0, 1)))
  |> because("the provided positive decimal integer is invalid")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("-f", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(DecimalDigit, "f", ParserPosition(0, 1)))
  |> because("the provided negative decimal integer is invalid")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("0d", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigit, ParserPosition(0, 2)))
  |> because("no input was left to parse")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("0D", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(DecimalDigit, ParserPosition(0, 2)))
  |> because("no input was left to parse")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("0Df", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(DecimalDigit, "f", ParserPosition(0, 2)))
  |> because("the provided prefixed decimal integer is invalid")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("0d110", 0, _)
  |> should.be_ok()
  |> should.equal(110)
  |> because("the parser was given a valid prefixed decimal integer")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("110", 0, _)
  |> should.be_ok()
  |> should.equal(110)
  |> because("the parser was given a valid unprefixed decimal integer")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("+10", 0, _)
  |> should.be_ok()
  |> should.equal(10)
  |> because("the parser was given a valid positive decimal integer")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("-101", 0, _)
  |> should.be_ok()
  |> should.equal(-101)
  |> because("the parser was given a valid negative decimal integer")

  pickle.decimal_integer(fn(_, integer) { integer })
  |> pickle.parse("10abc", 0, _)
  |> should.be_ok()
  |> should.equal(10)
  |> because("the parser stopped consuming input after the decimal integer")

  pickle.string("[", pickle.drop)
  |> pickle.then(
    pickle.decimal_integer(fn(value, integer) { Point(..value, x: integer) }),
  )
  |> pickle.then(pickle.string(",", pickle.drop))
  |> pickle.then(
    pickle.decimal_integer(fn(value, integer) { Point(..value, y: integer) }),
  )
  |> pickle.then(pickle.string("]", pickle.drop))
  |> pickle.parse("[-5,10]", Point(0, 0), _)
  |> should.be_ok()
  |> should.equal(Point(-5, 10))
  |> because("the point could be parsed")

  pickle.decimal_integer(fn(value, integer) { value + integer })
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.decimal_integer(fn(value, integer) { value + integer }))
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.decimal_integer(pickle.drop))
  |> pickle.parse("100;-1000;11", 0, _)
  |> should.be_ok()
  |> should.equal(-900)
  |> because("the last decimal integer is not added to the sum")
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
  |> pickle.parse("0x", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(HexadecimalDigit, ParserPosition(0, 2)))
  |> because("no input was left to parse")

  pickle.hexadecimal_integer(fn(_, integer) { integer })
  |> pickle.parse("0X", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(HexadecimalDigit, ParserPosition(0, 2)))
  |> because("no input was left to parse")

  pickle.hexadecimal_integer(fn(_, integer) { integer })
  |> pickle.parse("0x-f", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(HexadecimalDigit, "-", ParserPosition(0, 2)))
  |> because("the provided prefixed hexadecimal integer is invalid")

  pickle.hexadecimal_integer(fn(_, integer) { integer })
  |> pickle.parse("0xefefef", 0, _)
  |> should.be_ok()
  |> should.equal(15_724_527)
  |> because("the parser was given a valid prefixed hexadecimal integer")

  pickle.hexadecimal_integer(fn(_, integer) { integer })
  |> pickle.parse("1F", 0, _)
  |> should.be_ok()
  |> should.equal(31)
  |> because("the parser was given a valid unprefixed hexadecimal integer")

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
  |> pickle.parse("0XFEsomething else", 0, _)
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
  |> pickle.parse("[0xc,1A]", Point(0, 0), _)
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
  |> pickle.parse("1F;0x9e;-FFFeee", 0, _)
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
  |> pickle.parse("0o", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(OctalDigit, ParserPosition(0, 2)))
  |> because("no input was left to parse")

  pickle.octal_integer(fn(_, integer) { integer })
  |> pickle.parse("0O", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(OctalDigit, ParserPosition(0, 2)))
  |> because("no input was left to parse")

  pickle.octal_integer(fn(_, integer) { integer })
  |> pickle.parse("0o-7", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(OctalDigit, "-", ParserPosition(0, 2)))
  |> because("the provided prefixed octal integer is invalid")

  pickle.octal_integer(fn(_, integer) { integer })
  |> pickle.parse("0o77", 0, _)
  |> should.be_ok()
  |> should.equal(63)
  |> because("the parser was given a valid prefixed octal integer")

  pickle.octal_integer(fn(_, integer) { integer })
  |> pickle.parse("12", 0, _)
  |> should.be_ok()
  |> should.equal(10)
  |> because("the parser was given a valid unprefixed octal integer")

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
  |> pickle.parse("0O11something else", 0, _)
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
  |> pickle.parse("[0o45,-11]", Point(0, 0), _)
  |> should.be_ok()
  |> should.equal(Point(37, -9))
  |> because("the point could be parsed")

  pickle.octal_integer(fn(value, integer) { value + integer })
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.octal_integer(fn(value, integer) { value + integer }))
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.octal_integer(pickle.drop))
  |> pickle.parse("-15;0o11;77", 0, _)
  |> should.be_ok()
  |> should.equal(-4)
  |> because("the last octal integer is not added to the sum")
}

pub fn integer_test() {
  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("not_an_integer", 0, _)
  |> should.be_error()
  |> should.equal(
    OneOfError([
      UnexpectedToken(OctalDigit, "n", ParserPosition(0, 0)),
      UnexpectedToken(HexadecimalDigit, "n", ParserPosition(0, 0)),
      UnexpectedToken(BinaryDigit, "n", ParserPosition(0, 0)),
      UnexpectedToken(DecimalDigit, "n", ParserPosition(0, 0)),
    ]),
  )
  |> because("the provided input is not an integer")

  pickle.string("abc", pickle.drop)
  |> pickle.then(pickle.integer(fn(_, integer) { integer }))
  |> pickle.parse("abc-", 0, _)
  |> should.be_error()
  |> should.equal(
    OneOfError([
      UnexpectedEof(OctalDigit, ParserPosition(0, 4)),
      UnexpectedEof(HexadecimalDigit, ParserPosition(0, 4)),
      UnexpectedEof(BinaryDigit, ParserPosition(0, 4)),
      UnexpectedEof(DecimalDigit, ParserPosition(0, 4)),
    ]),
  )
  |> because("no input was left to parse")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("", 0, _)
  |> should.be_error()
  |> should.equal(
    OneOfError([
      UnexpectedEof(OctalDigit, ParserPosition(0, 0)),
      UnexpectedEof(HexadecimalDigit, ParserPosition(0, 0)),
      UnexpectedEof(BinaryDigit, ParserPosition(0, 0)),
      UnexpectedEof(DecimalDigit, ParserPosition(0, 0)),
    ]),
  )
  |> because("no input was left to parse")

  pickle.string("abd", pickle.drop)
  |> pickle.then(pickle.integer(fn(_, integer) { integer }))
  |> pickle.parse("abc2000", 0, _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abd"), "abc", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("250", 0, _)
  |> should.be_ok()
  |> should.equal(250)
  |> because("the parser was given a valid integer")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("+120", 0, _)
  |> should.be_ok()
  |> should.equal(120)
  |> because("the parser was given a valid integer")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("-75", 0, _)
  |> should.be_ok()
  |> should.equal(-75)
  |> because("the parser was given a valid integer")

  pickle.integer(fn(_, integer) { integer })
  |> pickle.parse("5005abc", 0, _)
  |> should.be_ok()
  |> should.equal(5005)
  |> because("the parser stopped consuming input after the integer")

  pickle.string("[", pickle.drop)
  |> pickle.then(
    pickle.integer(fn(value, integer) { Point(..value, x: integer) }),
  )
  |> pickle.then(pickle.string(",", pickle.drop))
  |> pickle.then(
    pickle.integer(fn(value, integer) { Point(..value, y: integer) }),
  )
  |> pickle.then(pickle.string("]", pickle.drop))
  |> pickle.parse("[20,72]", Point(0, 0), _)
  |> should.be_ok()
  |> should.equal(Point(20, 72))
  |> because("the point could be parsed")

  pickle.integer(fn(value, integer) { value + integer })
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.integer(fn(value, integer) { value + integer }))
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.integer(fn(value, integer) { value + integer }))
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.integer(fn(value, integer) { value + integer }))
  |> pickle.then(pickle.string(";", pickle.drop))
  |> pickle.then(pickle.integer(pickle.drop))
  |> pickle.parse("100;0b10;0xca;0o77;400", 0, _)
  |> should.be_ok()
  |> should.equal(367)
  |> because("the last integer is not added to the sum")
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
  pickle.until("=", fn(value, string) { value <> string })
  |> pickle.parse("let test value;", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(String("="), ParserPosition(0, 15)))
  |> because("the terminator could not be found")

  pickle.until("=", fn(value, string) { value <> string })
  |> pickle.parse("let test = \"value\";", "", _)
  |> should.be_ok()
  |> should.equal("let test ")
  |> because("the terminator could be found")

  pickle.until("EQUALS", fn(value, string) { value <> string })
  |> pickle.parse("var test EQUALS something", "", _)
  |> should.be_ok()
  |> should.equal("var test ")
  |> because("the terminator could be found")

  pickle.many(
    "",
    pickle.until("=", fn(value, string) { value <> string })
      |> pickle.then(pickle.string("=", pickle.drop)),
    fn(value, string) { [string, ..value] },
  )
  |> pickle.parse("let test = \"value\";\nlet test2 = \"value2\";", [], _)
  |> should.be_ok()
  |> should.equal([" \"value\";\nlet test2 ", "let test "])
  |> because("the terminator could be found two times")
}

pub fn skip_until_test() {
  pickle.skip_until("=")
  |> pickle.parse("let test value;", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedEof(String("="), ParserPosition(0, 15)))
  |> because("the terminator could not be found")

  pickle.skip_until("=")
  |> pickle.then(pickle.until(";", fn(value, string) { value <> string }))
  |> pickle.parse("let test = \"value\";", "", _)
  |> should.be_ok()
  |> should.equal("= \"value\"")
  |> because("the terminator could be found")

  pickle.skip_until("EQUALS")
  |> pickle.then(pickle.until(" ", fn(value, string) { value <> string }))
  |> pickle.parse("var test EQUALS something", "", _)
  |> should.be_ok()
  |> should.equal("EQUALS")
  |> because("the terminator could be found")
}

pub fn whitespace_test() {
  pickle.string("aa", fn(value, string) { value <> string })
  |> pickle.then(pickle.whitespace(fn(value, string) { value <> string }))
  |> pickle.parse("ab\t \n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("aa"), "ab", ParserPosition(0, 1)))
  |> because("a prior parser failed")

  pickle.whitespace(fn(value, string) { value <> string })
  |> pickle.parse("\t \n", "", _)
  |> should.be_ok()
  |> should.equal("\t \n")
  |> because("the entire input consisted of whitespace")

  pickle.whitespace(fn(value, string) { value <> string })
  |> pickle.parse("\t \nabc", "", _)
  |> should.be_ok()
  |> should.equal("\t \n")
  |> because("it consumed all whitespace until reaching non-whitespace tokens")

  pickle.whitespace(fn(value, string) { value <> string })
  |> pickle.parse("not_whitespace\t \n", "", _)
  |> should.be_ok()
  |> should.equal("")
  |> because("the input didn't start with whitespace")
}

pub fn skip_whitespace_test() {
  pickle.string("aa", fn(value, string) { value <> string })
  |> pickle.then(pickle.skip_whitespace())
  |> pickle.parse("ab\t \n", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("aa"), "ab", ParserPosition(0, 1)))
  |> because("a prior parser failed")

  pickle.string("something", fn(value, string) { value <> string })
  |> pickle.then(pickle.skip_whitespace())
  |> pickle.then(pickle.string("abc", fn(value, string) { value <> string }))
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

pub fn one_of_test() {
  pickle.one_of([
    pickle.string("abc", fn(value, string) { value <> string }),
    pickle.string("abd", fn(value, string) { value <> string }),
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

  pickle.string("123", fn(value, string) { value <> string })
  |> pickle.then(
    pickle.one_of([
      pickle.string("abc", fn(value, string) { value <> string }),
      pickle.string("abd", fn(value, string) { value <> string }),
    ]),
  )
  |> pickle.parse("abc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("123"), "a", ParserPosition(0, 0)))
  |> because("a prior parser failed")

  pickle.one_of([
    pickle.string("abc", fn(value, string) { value <> string }),
    pickle.string("abd", fn(value, string) { value <> string }),
  ])
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal("abc")
  |> because("the first given parser succeeded")

  pickle.one_of([
    pickle.string("abc", fn(value, string) { value <> string }),
    pickle.string("abd", fn(value, string) { value <> string }),
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
  pickle.string("abd", fn(value, string) { [string, ..value] })
  |> pickle.then(pickle.return(10))
  |> pickle.parse("abc", [], _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(String("abd"), "abc", ParserPosition(0, 2)))
  |> because("a prior parser failed")

  pickle.string("abc", fn(value, string) { [string, ..value] })
  |> pickle.then(pickle.return(20))
  |> pickle.parse("abc", [], _)
  |> should.be_ok()
  |> should.equal(20)
  |> because("the value has been overridden")
}

pub fn eof_test() {
  pickle.string("ab\nd", fn(value, string) { value <> string })
  |> pickle.then(pickle.eof())
  |> pickle.parse("ab\nc", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(
    String("ab\nd"),
    "ab\nc",
    ParserPosition(1, 0),
  ))
  |> because("a prior parser failed")

  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.eof())
  |> pickle.parse("abcd", "", _)
  |> should.be_error()
  |> should.equal(UnexpectedToken(Eof, "d", ParserPosition(0, 3)))
  |> because("there was input left to parse")

  pickle.string("abc", fn(value, string) { value <> string })
  |> pickle.then(pickle.eof())
  |> pickle.parse("abc", "", _)
  |> should.be_ok()
  |> should.equal("abc")
  |> because("there was no input left to parse")
}

type Point(a) {
  Point(x: a, y: a)
}

type TestError {
  Something(token: String, pos: ParserPosition)
  Whatever
}
