import gleeunit/should
import pickle.{
  type Parser, type ParserFailure, BinaryDigit, DecimalDigit, GuardError,
  HexadecimalDigit, OneOfError, ParserPosition, String, UnexpectedEof,
  UnexpectedToken,
}

pub fn points_parser_test() {
  pickle.parse("(5,10),[2,-5],(0,-1)", [], points_parser())
  |> should.be_ok()
  |> should.equal([Point(0, -1), Point(2, -5), Point(5, 10)])

  pickle.parse("[-2,5]", [], points_parser())
  |> should.be_ok()
  |> should.equal([Point(-2, 5)])

  pickle.parse("", [], points_parser())
  |> should.be_ok()
  |> should.equal([])

  pickle.parse("invalid", [], points_parser())
  |> should.be_ok()
  |> should.equal([])

  pickle.parse("(5,10),[-2,5],invalid", [], points_parser())
  |> should.be_ok()
  |> should.equal([Point(-2, 5), Point(5, 10)])
}

pub fn point_parser_test() {
  pickle.parse("(5,10)", new_point(), point_parser())
  |> should.be_ok()
  |> should.equal(Point(5, 10))

  pickle.parse("[-2,5]", new_point(), point_parser())
  |> should.be_ok()
  |> should.equal(Point(-2, 5))

  pickle.parse("[-20,5]", new_point(), point_parser())
  |> should.be_error()
  |> should.equal(GuardError(ValueIsLessThanMinusTen(X), ParserPosition(0, 7)))

  pickle.parse("(20,5)", new_point(), point_parser())
  |> should.be_error()
  |> should.equal(GuardError(ValueIsGreaterThanTen(X), ParserPosition(0, 6)))

  pickle.parse("[8,15]", new_point(), point_parser())
  |> should.be_error()
  |> should.equal(GuardError(ValueIsGreaterThanTen(Y), ParserPosition(0, 6)))

  pickle.parse("(-4,-11)", new_point(), point_parser())
  |> should.be_error()
  |> should.equal(GuardError(ValueIsLessThanMinusTen(Y), ParserPosition(0, 8)))

  pickle.parse("5,10", new_point(), point_parser())
  |> should.be_error()
  |> should.equal(
    OneOfError([
      UnexpectedToken(String("["), "5", ParserPosition(0, 0)),
      UnexpectedToken(String("("), "5", ParserPosition(0, 0)),
    ]),
  )

  pickle.parse("(,)", new_point(), point_parser())
  |> should.be_error()
  |> should.equal(
    OneOfError([
      UnexpectedToken(String("["), "(", ParserPosition(0, 0)),
      OneOfError([
        UnexpectedToken(HexadecimalDigit, ",", ParserPosition(0, 1)),
        UnexpectedToken(BinaryDigit, ",", ParserPosition(0, 1)),
        UnexpectedToken(DecimalDigit, ",", ParserPosition(0, 1)),
      ]),
    ]),
  )

  pickle.parse("", new_point(), point_parser())
  |> should.be_error()
  |> should.equal(
    OneOfError([
      UnexpectedEof(String("["), ParserPosition(0, 0)),
      UnexpectedEof(String("("), ParserPosition(0, 0)),
    ]),
  )
}

type Point {
  Point(x: Int, y: Int)
}

type PointAxis {
  X
  Y
}

type PointError {
  ValueIsLessThanMinusTen(axis: PointAxis)
  ValueIsGreaterThanTen(axis: PointAxis)
}

fn new_point() -> Point {
  Point(0, 0)
}

fn points_parser() -> fn(Parser(List(Point))) ->
  Result(Parser(List(Point)), ParserFailure(PointError)) {
  pickle.many(
    new_point(),
    point_parser()
      |> pickle.then(
        pickle.one_of([pickle.string(",", pickle.drop), pickle.eof()]),
      ),
    fn(points, point) { [point, ..points] },
  )
}

fn point_parser() -> fn(Parser(Point)) ->
  Result(Parser(Point), ParserFailure(PointError)) {
  pickle.one_of([do_point_parser("(", ")"), do_point_parser("[", "]")])
  |> pickle.then(validate_x_value())
  |> pickle.then(validate_y_value())
}

fn do_point_parser(
  opening_bracket: String,
  closing_bracket: String,
) -> fn(Parser(Point)) -> Result(Parser(Point), ParserFailure(PointError)) {
  pickle.string(opening_bracket, pickle.drop)
  |> pickle.then(pickle.integer(fn(point, x) { Point(..point, x: x) }))
  |> pickle.then(pickle.string(",", pickle.drop))
  |> pickle.then(pickle.integer(fn(point, y) { Point(..point, y: y) }))
  |> pickle.then(pickle.string(closing_bracket, pickle.drop))
}

fn validate_x_value() -> fn(Parser(Point)) ->
  Result(Parser(Point), ParserFailure(PointError)) {
  pickle.guard(fn(point: Point) { point.x >= -10 }, ValueIsLessThanMinusTen(X))
  |> pickle.then(pickle.guard(
    fn(point: Point) { point.x <= 10 },
    ValueIsGreaterThanTen(X),
  ))
}

fn validate_y_value() -> fn(Parser(Point)) ->
  Result(Parser(Point), ParserFailure(PointError)) {
  pickle.guard(fn(point: Point) { point.y >= -10 }, ValueIsLessThanMinusTen(Y))
  |> pickle.then(pickle.guard(
    fn(point: Point) { point.y <= 10 },
    ValueIsGreaterThanTen(Y),
  ))
}
