import gparsec
import startest.{it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn placeholder_tests() {
  it("returns \"placeholder\"", fn() {
    gparsec.placeholder()
    |> expect.to_equal("placeholder")
  })
}
