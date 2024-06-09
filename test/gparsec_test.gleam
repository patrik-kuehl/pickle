import gparsec.{Parser, ParserPosition}
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn input_tests() {
  describe("gparsec/input", [
    it("returns a new parser", fn() {
      gparsec.input(tokens: "abc", initial_value: [])
      |> expect.to_be_ok()
      |> expect.to_equal(Parser(["a", "b", "c"], ParserPosition(0, 0), []))
    }),
  ])
}
