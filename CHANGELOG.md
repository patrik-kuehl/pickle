# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2024-08-01

### Added

-   Added `pickle/times` to apply a given parser a specified amount of times.
-   Added `pickle/digit` to parse a single decimal digit.
-   Added `pickle/octal_digit` to parse a single octal digit.
-   Added `pickle/hexadecimal_digit` to parse a single hexadecimal digit.
-   Added `pickle/binary_digit` to parse a single binary digit.

### Changed

-   Changed `pickle/integer` to only parse decimal integers.

### Removed

-   Removed `pickle/decimal_integer` in favor of `pickle/integer`.

## [0.5.0] - 2024-07-28

### Added

-   Added `pickle/do` to apply the initial value to a given parser.

## [0.4.0] - 2024-07-26

### Added

-   Added `pickle/any` to parse a single token of any kind.
-   Added `pickle/skip_until1` to skip one to `n` tokens until the terminator succeeds.
-   Added `pickle/until1` to apply a given parser one to `n` times until the terminator succeeds.

## [0.3.0] - 2024-07-20

### Added

-   Added `pickle/eol` to parse an end-of-line character.
-   Added `pickle/not` to fail if the given parser succeeds.
-   Added `pickle/lookahead` to lookahead whether the given parser succeeds.
-   Added `pickle/skip_whitespace1` to skip one to `n` whitespace tokens.
-   Added `pickle/whitespace1` to parse one to `n` whitespace tokens.

## [0.2.0] - 2024-07-18

### Added

-   Added `pickle/many1` to parse tokens one to `n` times until the given parser fails.
-   Added `pickle/uppercase_ascii_letter` to parse an uppercase ASCII letter.
-   Added `pickle/lowercase_ascii_letter` to parse a lowercase ASCII letter.
-   Added `pickle/ascii_letter` to parse an ASCII letter.

## [0.1.0] - 2024-07-14

### Added

-   Added `pickle/eof` to validate that there are no further tokens to parse.
-   Added `pickle/return` to modify the parser's value without consuming any tokens.
-   Added `pickle/one_of` to parse tokens by trying a set of given parsers.
-   Added `pickle/guard` to validate the value of the parser.
-   Added `pickle/map_error` to map an error.
-   Added `pickle/map` to map the value of the parser.
-   Added `pickle/skip_whitespace` to skip zero to `n` whitespace tokens.
-   Added `pickle/whitespace` to parse zero to `n` whitespace tokens.
-   Added `pickle/float` to parse tokens as a float.
-   Added `pickle/integer` to parse tokens as an integer.
-   Added `pickle/octal_integer` to parse tokens as an octal integer.
-   Added `pickle/hexadecimal_integer` to parse tokens as a hexadecimal integer.
-   Added `pickle/decimal_integer` to parse tokens as a decimal integer.
-   Added `pickle/binary_integer` to parse tokens as a binary integer.
-   Added `pickle/skip_until` to skip zero to `n` tokens until the terminator succeeds.
-   Added `pickle/until` to apply a given parser zero to `n` times until the terminator succeeds.
-   Added `pickle/many` to parse tokens zero to `n` times until the given parser fails.
-   Added `pickle/optional` to ignore and backtrack the parser in case the given parser fails.
-   Added `pickle/string` to parse a specific string.
-   Added `pickle/then` to chain parsers.
-   Added `pickle/parse` to parse input via a given parser.

[unreleased]: https://github.com/patrik-kuehl/pickle/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/patrik-kuehl/pickle/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/patrik-kuehl/pickle/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/patrik-kuehl/pickle/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/patrik-kuehl/pickle/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/patrik-kuehl/pickle/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/patrik-kuehl/pickle/releases/tag/v0.1.0
