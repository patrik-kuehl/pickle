# Getting Started

This guide will help you getting familiar with Pickle by going through multiple challenges of increasing complexity.

## Parsing Simple Structures

Let's assume we're dealing with a simple format that represents a point with two axes that we receive as `(x,y)`.

To get started, let's first define a type for this.

```gleam
type Point {
  Point(x: Int, y: Int)
}
```

The format we receive is really simple. We have an opening bracket, some integer value that represents `x`, a comma,
some integer value that represents `y`, and a closing bracket.

Let's take a look at how a parser for this can look like.

```gleam
import pickle.{type Parser, type ParserFailure}

// ...

fn point_parser() -> fn(Parser(Point)) ->
  Result(Parser(Point), ParserFailure(Nil)) {
  pickle.string("(", pickle.drop)
  |> pickle.then(pickle.integer(fn(point, x) { Point(..point, x: x) }))
  |> pickle.then(pickle.string(",", pickle.drop))
  |> pickle.then(pickle.integer(fn(point, y) { Point(..point, y: y) }))
  |> pickle.then(pickle.string(")", pickle.drop))
}
```

This is how parsers in Pickle look like, no matter how complex they are.

We start with `pickle/string` to parse a specific string, in this case the opening bracket. Since we don't need it
eventually, we drop it via `pickle/drop`, which is a mapper provided by Pickle to drop the parsed value.

We then (no pun intended) use `pickle/then` to combine two parsers. You'll be using this a lot when using Pickle and for
brevity reasons, `pickle/then` won't be mentioned anymore from this point on.

The prior parser is combined with `pickle/integer` to parse an integer, our `x` value, which we use to create a new
point with our acquired `x` value. `pickle/integer` parses the given tokens as long as they can be represented as an
integer, so it doesn't expect an integer of a specific length.

`pickle/integer` supports different numeric formats (binary, decimal, hexadecimal and octal). If you need or want to
parse an integer of a specific numeric format, you can take a look at Pickle's module documentation. In this guide we'll
only be using decimal integers, but feel free to play around.

We then continue our adventure with `pickle/string` to parse and drop the comma.

Afterwards we need to parse the `y` value of our point and as you might have guessed, use `pickle/integer` for this
again.

Lastly, we hit the jackpot by using `pickle/string` to parse and drop the closing bracket.

Well done! Now we have a basic parser that we can use to parse points.

To apply the parser we use `pickle/parse`.

```gleam
import pickle.{type Parser, type ParserFailure}

/// ...

fn new_point() -> Point {
  Point(0, 0)
}

pub fn main() {
  let assert Ok(point) =
    pickle.parse("(20,10)", new_point(), point_parser())

  string.inspect(point) |> io.print() // prints "Point(20, 10)"
}
```

`pickle/parse` takes three arguments. The first one is the input string, the second one the initial value, and the third
one the parser to apply. The initial value doesn't have to be a simple data structure. When parsing DSLs or even
programming languages you most probably want to use a custom AST type to initialize the parser value with.

## Parsing Variants

Let's add some seasoning to our problem domain here. Our point can now come in different shapes, `(x,y)` and `[x,y]`.

Before you write two parsers with a lot of duplication for each shape, take a look at the following parsers and compare
it to the prior one we've written.

```gleam
import pickle.{type Parser, type ParserFailure}

// ...

fn do_point_parser(
  opening_bracket: String,
  closing_bracket: String,
) -> fn(Parser(Point)) -> Result(Parser(Point), ParserFailure(Nil)) {
  pickle.string(opening_bracket, pickle.drop)
  |> pickle.then(pickle.integer(fn(point, x) { Point(..point, x: x) }))
  |> pickle.then(pickle.string(",", pickle.drop))
  |> pickle.then(pickle.integer(fn(point, y) { Point(..point, y: y) }))
  |> pickle.then(pickle.string(closing_bracket, pickle.drop))
}

fn point_parser() -> fn(Parser(Point)) ->
  Result(Parser(Point), ParserFailure(Nil)) {
  pickle.one_of([do_point_parser("(", ")"), do_point_parser("[", "]")])
}
```

We handle both kinds of brackets by using `pickle/one_of`, which takes zero to `n` parsers to try in order, and in this
case we feed it with two parsers by using our parameterized `do_point_parser` function, enabling us to specify different
opening and closing brackets.

Let's see it in action.

```gleam
import pickle.{type Parser, type ParserFailure}

/// ...

pub fn main() {
  let assert Ok(first_point) =
    pickle.parse("(20,-5)", new_point(), point_parser())

  let assert Ok(second_point) =
    pickle.parse("[10,325]", new_point(), point_parser())

  string.inspect(first_point) |> io.print() // prints "Point(20, -5)"
  string.inspect(second_point) |> io.print() // prints "Point(10, 325)"
}
```

## Perform Validation

Pickle offers the possibility to validate the value of the parser. To showcase this, a new requirement has been
delivered by our fellow UPS driver.

The `x` and `y` values of our point cannot be less than -10 and greater than 10. Why? Why not.

Let's first define a custom error type for our validation purposes to reflect this requirement.

```gleam
type PointAxis {
  X
  Y
}

type PointError {
  ValueIsLessThanMinusTen(axis: PointAxis)
  ValueIsGreaterThanTen(axis: PointAxis)
}
```

We then need to replace the type parameter of `ParserFailure` with our custom error type to tell Pickle what error type
to expect in case of a validation failure.

```gleam
import pickle.{type Parser, type ParserFailure}

// ...

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

fn point_parser() -> fn(Parser(Point)) ->
  Result(Parser(Point), ParserFailure(PointError)) {
  pickle.one_of([do_point_parser("(", ")"), do_point_parser("[", "]")])
}
```

Now we need to add some validation. For this purpose we use `pickle/guard`.

```gleam
import pickle.{type Parser, type ParserFailure}

// ...

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

fn point_parser() -> fn(Parser(Point)) ->
  Result(Parser(Point), ParserFailure(PointError)) {
  pickle.one_of([do_point_parser("(", ")"), do_point_parser("[", "]")])
  |> pickle.then(validate_x_value())
  |> pickle.then(validate_y_value())
}
```

We could certainly reduce the duplication in this validation logic and replace these magic numbers with constants, but
that's not the focus here.

From now on we've got a parser with validation logic to ensure our points cannot have `x` and `y` values that are less
than -10 and greater than 10.

Trying to parse a point with invalid values now results in a `GuardError`, which contains our error value.

```gleam
import pickle.{type Parser, type ParserFailure}

/// ...

pub fn main() {
  let assert Ok(point) =
    pickle.parse("(20,-5)", new_point(), point_parser())

  let assert Error(GuardError(error)) =
    pickle.parse("[10,325]", new_point(), point_parser())

  string.inspect(first_point) |> io.print() // prints "Point(20, -5)"
  string.inspect(error) |> io.print() // prints "ValueIsGreaterThanTen(Y)"
}
```

Pickle not only returns errors when some validation failed, but also when some of the parsers failed to parse the input.
You should keep in mind that the `GuardError` type is exclusive to validation-specific failures.

## Parsing Sequences

Fine, we're able to parse a point, but what about a list of points?

Let's assume the receive a list of points as a comma-separated list (e.g., `(2,-4),(10,0),[-5,6]`).

Pickle happens to offer just the right tool for this job, `pickle/many`. This parser applies the given parser zero to
`n` times until it fails and is offering us a way to accumulate the collected points.

```gleam
import pickle.{type Parser, type ParserFailure}

// ...

fn points_parser() -> fn(Parser(List(Point))) ->
  Result(Parser(List(Point)), ParserFailure(PointError)) {
  pickle.many(
    new_point(),
    point_parser()
      |> pickle.then(
        pickle.one_of([pickle.string(",", pickle.drop), pickle.eof()]),
      ),
    pickle.prepend_to_list,
  )
}
```

Here we use our `point_parser` function combined with a parser to either parse a comma or EOF to set the head of the
parser to the next point. `pickle/many` runs our parser zero to `n` times until it fails. Each parser will be given a
blank point as an initial value. Afterwards we prepend the parsed point to our list of points via
`pickle/prepend_to_list`, which is another mapper provided by Pickle.

Keep in mind that `pickle/many` never fails and adheres to the best-effort error handling strategy. As soon as it
encounters invalid input it just stops consuming any more tokens and returns the collected items that could be parsed
until the point of failure.

This means that you could end up with no collected points (an empty list) because you provided invalid input to the
parser.

If the given parser fails due to some validation constraint, moving this validation logic outside of `pickle/many` might
be a viable option, so you're still able to convey validation issues to the consumer while letting `pickle/many` collect
items with an invalid state before running the validation. The best approach depends on your use case eventually.

```gleam
import pickle.{type Parser, type ParserFailure}

/// ...

pub fn main() {
  let assert Ok(points) =
    pickle.parse("(20,-5),[0,10]", [], points_parser())

  let assert Ok(points2) =
    pickle.parse("(20,-5),gibberish", [], points_parser())

  let assert Ok(nothing) =
    pickle.parse("[50,-50],(-100,25)", [], points_parser())

  let assert Ok(nothing2) =
    pickle.parse("gibberish", [], points_parser())

  string.inspect(points) |> io.print() // prints "[Point(0, 10), Point(20, -5)]"
  string.inspect(points2) |> io.print() // prints "[Point(20, -5)]"
  string.inspect(nothing) |> io.print() // prints "[]"
  string.inspect(nothing2) |> io.print() // prints "[]"
}
```

## You've Made It!

Congratulations! You've finished the getting started guide and learned about the fundamentals of Pickle. Happy parsing!

The tested final implementation of this parser can be found in `test/examples/point_test.gleam`.

## Additional Challenges

You could think about adding further shapes like `{x,y}`, or add support for another delimiter like a semicolon.

One thing to keep in mind is that Pickle is scannerless, thus there's no separate lexer to tokenize the input. This
means that the parser covers responsibilities usually taken care of by a lexer like handling whitespace. As of now, our
point parser cannot handle input with whitespace sprinkled in.

The parser will fail if we provide input like `(x, y)`, `( x,y )`, or `[x, y]`.

You could extend the parser to handle whitespace, in this case by ignoring it. For this you can use
`pickle/skip_whitespace`.
