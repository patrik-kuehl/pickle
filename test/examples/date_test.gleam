import pickle.{type ParserResult, ParserPosition, ValidationError}
import startest.{describe, it}
import startest/expect

/// Simple ISO 8601 Format
/// 
/// YYYY-MM-DDThh:mm:ss[Z]
///
/// The parser needs to be able to parse the given dates.
/// 
/// Constraints:
/// 
///     Year: >= 1000 and <= 9999
///     Month: >= 1 and <= 12
///     Day: >= 1 and <= 31
///     Hour: >= 0 and <= 23
///     Minute/Second: >= 0 and <= 59
pub fn date_tests() {
  describe("examples/date_test", [
    describe("parse_dates", [
      it(
        "returns all dates that are part of the given string when all dates are valid",
        fn() {
          pickle.parse(
            "2020-08-15T20:30:00Z\n2022-09-01T12:00:00Z\n2024-12-10T09:15:00\n",
            [],
            parse_dates,
          )
          |> expect.to_be_ok()
          |> expect.to_equal([
            Date(year: 2024, month: 12, day: 10, hour: 9, minute: 15, second: 0),
            Date(year: 2022, month: 9, day: 1, hour: 12, minute: 0, second: 0),
            Date(year: 2020, month: 8, day: 15, hour: 20, minute: 30, second: 0),
          ])
        },
      ),
    ]),
    describe("parse_date", [
      it("returns the date provided via the given string", fn() {
        pickle.parse("2020-08-15T20:30:00Z\n", create_blank_date(), parse_date)
        |> expect.to_be_ok()
        |> expect.to_equal(Date(
          year: 2020,
          month: 8,
          day: 15,
          hour: 20,
          minute: 30,
          second: 0,
        ))
      }),
      it("returns an error when the year is invalid", fn() {
        pickle.parse("500-08-15T20:30:00Z\n", create_blank_date(), parse_date)
        |> expect.to_be_error()
        |> expect.to_equal(ValidationError(
          invalid_year_error_message,
          ParserPosition(0, 3),
        ))
      }),
      it("returns an error when the month is invalid", fn() {
        pickle.parse("2015-40-01T20:30:00\n", create_blank_date(), parse_date)
        |> expect.to_be_error()
        |> expect.to_equal(ValidationError(
          invalid_month_error_message,
          ParserPosition(0, 7),
        ))
      }),
      it("returns an error when the day is invalid", fn() {
        pickle.parse("2010-10-35T20:30:00\n", create_blank_date(), parse_date)
        |> expect.to_be_error()
        |> expect.to_equal(ValidationError(
          invalid_day_error_message,
          ParserPosition(0, 10),
        ))
      }),
      it("returns an error when the hour is invalid", fn() {
        pickle.parse("2010-10-20T25:30:00\n", create_blank_date(), parse_date)
        |> expect.to_be_error()
        |> expect.to_equal(ValidationError(
          invalid_hour_error_message,
          ParserPosition(0, 13),
        ))
      }),
      it("returns an error when the minute is invalid", fn() {
        pickle.parse("2010-10-20T22:72:00\n", create_blank_date(), parse_date)
        |> expect.to_be_error()
        |> expect.to_equal(ValidationError(
          invalid_minute_error_message,
          ParserPosition(0, 16),
        ))
      }),
      it("returns an error when the second is invalid", fn() {
        pickle.parse("2010-10-20T22:30:62\n", create_blank_date(), parse_date)
        |> expect.to_be_error()
        |> expect.to_equal(ValidationError(
          invalid_second_error_message,
          ParserPosition(0, 19),
        ))
      }),
    ]),
  ])
}

const invalid_year_error_message = "a year must be >= 1000 and <= 9999"

const invalid_month_error_message = "a month must be >= 1 and <= 12"

const invalid_day_error_message = "a day must be >= 1 and <= 31"

const invalid_hour_error_message = "an hour must be >= 0 and <= 23"

const invalid_minute_error_message = "a minute must be >= 0 and <= 59"

const invalid_second_error_message = "a second must be >= 0 and <= 59"

type Date {
  Date(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int)
}

fn create_blank_date() -> Date {
  Date(0, 0, 0, 0, 0, 0)
}

fn parse_dates(prev: ParserResult(List(Date))) -> ParserResult(List(Date)) {
  prev
  |> pickle.repeat(create_blank_date(), parse_date)
}

fn parse_date(prev: ParserResult(Date)) -> ParserResult(Date) {
  prev
  |> parse_date_year()
  |> parse_date_month()
  |> parse_date_day()
  |> parse_date_hour()
  |> parse_date_minute()
  |> parse_date_second()
}

fn parse_date_year(prev: ParserResult(Date)) -> ParserResult(Date) {
  prev
  |> pickle.integer(fn(date, year) { Date(..date, year: year) })
  |> pickle.guard(has_valid_year, invalid_year_error_message)
  |> pickle.token("-", pickle.ignore_token)
}

fn parse_date_month(prev: ParserResult(Date)) -> ParserResult(Date) {
  prev
  |> pickle.integer(fn(date, month) { Date(..date, month: month) })
  |> pickle.guard(has_valid_month, invalid_month_error_message)
  |> pickle.token("-", pickle.ignore_token)
}

fn parse_date_day(prev: ParserResult(Date)) -> ParserResult(Date) {
  prev
  |> pickle.integer(fn(date, day) { Date(..date, day: day) })
  |> pickle.guard(has_valid_day, invalid_day_error_message)
  |> pickle.token("T", pickle.ignore_token)
}

fn parse_date_hour(prev: ParserResult(Date)) -> ParserResult(Date) {
  prev
  |> pickle.integer(fn(date, hour) { Date(..date, hour: hour) })
  |> pickle.guard(has_valid_hour, invalid_hour_error_message)
  |> pickle.token(":", pickle.ignore_token)
}

fn parse_date_minute(prev: ParserResult(Date)) -> ParserResult(Date) {
  prev
  |> pickle.integer(fn(date, minute) { Date(..date, minute: minute) })
  |> pickle.guard(has_valid_minute, invalid_minute_error_message)
  |> pickle.token(":", pickle.ignore_token)
}

fn parse_date_second(prev: ParserResult(Date)) -> ParserResult(Date) {
  prev
  |> pickle.integer(fn(date, second) { Date(..date, second: second) })
  |> pickle.guard(has_valid_second, invalid_second_error_message)
  |> pickle.optional(pickle.token(_, "Z", pickle.ignore_token))
  |> pickle.token("\n", pickle.ignore_token)
}

fn has_valid_year(date: Date) -> Bool {
  date.year >= 1000 && date.year <= 9999
}

fn has_valid_month(date: Date) -> Bool {
  date.month >= 1 && date.month <= 12
}

fn has_valid_day(date: Date) -> Bool {
  date.day >= 1 && date.day <= 31
}

fn has_valid_hour(date: Date) -> Bool {
  date.hour >= 0 && date.hour <= 23
}

fn has_valid_minute(date: Date) -> Bool {
  date.minute >= 0 && date.minute <= 59
}

fn has_valid_second(date: Date) -> Bool {
  date.second >= 0 && date.second <= 59
}
