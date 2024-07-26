[![Package Version](https://img.shields.io/hexpm/v/pickle)](https://hex.pm/packages/pickle)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/pickle)
![Erlang-compatible](https://img.shields.io/badge/target-erlang-a2003e)
![JavaScript-compatible](https://img.shields.io/badge/target-javascript-f1e05a)

# Pickle 🥒

A parser combinator library for Gleam that supports all targets.

Pickle's API does heavily rely on pipelines, thus you can create powerful parsers by chaining multiple parsers together
with the pipe operator.

Pickle also takes a different approach on its API design. In Pickle you provide an initial value to the parser (e.g., an
empty string, list, or AST container) that's being transformed during parsing. Parsers often come with mapper
parameters, which let you control how to transform the current value with the parsed value of the respective parser.

## Demo 🥒

```gleam
import gleam/io
import gleam/string
import pickle.{type Parser}

type Point {
  Point(x: Int, y: Int)
}

fn new_point() -> Point {
  Point(0, 0)
}

fn point_parser() -> Parser(Point, Point, String) {
  pickle.string("(", pickle.drop)
  |> pickle.then(pickle.integer(fn(point, x) { Point(..point, x: x) }))
  |> pickle.then(pickle.string(",", pickle.drop))
  |> pickle.then(pickle.integer(fn(point, y) { Point(..point, y: y) }))
  |> pickle.then(pickle.string(")", pickle.drop))
}

pub fn main() {
  let assert Ok(point) =
    pickle.parse("(100,-25)", new_point(), point_parser())

  string.inspect(point) |> io.print() // prints "Point(100, -25)"
}
```

## Changelog 🥒

Take a look at the [changelog](https://github.com/patrik-kuehl/pickle/blob/main/CHANGELOG.md) to get an overview of each
release and its changes.

## Contribution Guidelines 🥒

More information can be found [here](https://github.com/patrik-kuehl/pickle/blob/main/CONTRIBUTING.md).

## License 🥒

Pickle is licensed under the [MIT license](https://github.com/patrik-kuehl/pickle/blob/main/LICENSE.md).
