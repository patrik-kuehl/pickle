# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

-   Added `pickle/eof` to validate that there are no further tokens to parse.
-   Added `pickle/return` to modify the parser's value without consuming any tokens.
-   Added `pickle/one_of` to parse tokens by trying a set of given parsers.
-   Added `pickle/guard` to validate the value of the parser.
-   Added `pickle/map` to map the value of the parser.
-   Added `pickle/skip_whitespace` to skip zero to `n` whitespace tokens.
-   Added `pickle/whitespace` to parse zero to `n` whitespace tokens.
-   Added `pickle/float` to parse tokens as a float.
-   Added `pickle/integer` to parse tokens as an integer.
-   Added `pickle/skip_until` to skip zero to `n` tokens until reaching a specific terminator.
-   Added `pickle/until` to parse zero to `n` tokens until reaching a specific terminator.
-   Added `pickle/many` to parse tokens zero to `n` times until the given parser fails.
-   Added `pickle/optional` to ignore and backtrack the parser in case the given parser fails.
-   Added `pickle/string` to parse a specific string.
-   Added `pickle/then` to chain parsers.
-   Added `pickle/parse` to parse a set of tokens via a given parser.
