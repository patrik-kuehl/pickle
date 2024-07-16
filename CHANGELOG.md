# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
-   Added `pickle/skip_until` to skip zero to `n` tokens until reaching a specific terminator.
-   Added `pickle/until` to parse zero to `n` tokens until reaching a specific terminator.
-   Added `pickle/many` to parse tokens zero to `n` times until the given parser fails.
-   Added `pickle/optional` to ignore and backtrack the parser in case the given parser fails.
-   Added `pickle/string` to parse a specific string.
-   Added `pickle/then` to chain parsers.
-   Added `pickle/parse` to parse input via a given parser.

[unreleased]: https://github.com/patrik-kuehl/pickle/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/patrik-kuehl/pickle/releases/tag/v0.1.0
