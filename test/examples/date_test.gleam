import pickle.{type Parser, type ParserFailure, GuardError, ParserPosition}
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
            "2020-08-15T20:30:00Z\n2022-09-01T12:00:00Z\n2024-12-10T09:15:00",
            [],
            parse_dates(),
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
        pickle.parse("2020-08-15T20:30:00Z", create_blank_date(), parse_date())
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
        pickle.parse("500-08-15T20:30:00Z", create_blank_date(), parse_date())
        |> expect.to_be_error()
        |> expect.to_equal(GuardError(InvalidYear, ParserPosition(0, 3)))
      }),
      it("returns an error when the month is invalid", fn() {
        pickle.parse("2015-40-01T20:30:00", create_blank_date(), parse_date())
        |> expect.to_be_error()
        |> expect.to_equal(GuardError(InvalidMonth, ParserPosition(0, 7)))
      }),
      it("returns an error when the day is invalid", fn() {
        pickle.parse("2010-10-35T20:30:00", create_blank_date(), parse_date())
        |> expect.to_be_error()
        |> expect.to_equal(GuardError(InvalidDay, ParserPosition(0, 10)))
      }),
      it("returns an error when the hour is invalid", fn() {
        pickle.parse("2010-10-20T25:30:00", create_blank_date(), parse_date())
        |> expect.to_be_error()
        |> expect.to_equal(GuardError(InvalidHour, ParserPosition(0, 13)))
      }),
      it("returns an error when the minute is invalid", fn() {
        pickle.parse("2010-10-20T22:72:00", create_blank_date(), parse_date())
        |> expect.to_be_error()
        |> expect.to_equal(GuardError(InvalidMinute, ParserPosition(0, 16)))
      }),
      it("returns an error when the second is invalid", fn() {
        pickle.parse("2010-10-20T22:30:62", create_blank_date(), parse_date())
        |> expect.to_be_error()
        |> expect.to_equal(GuardError(InvalidSecond, ParserPosition(0, 19)))
      }),
    ]),
  ])
}

type Date {
  Date(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int)
}

type InvalidDateError {
  InvalidYear
  InvalidMonth
  InvalidDay
  InvalidHour
  InvalidMinute
  InvalidSecond
}

fn create_blank_date() -> Date {
  Date(0, 0, 0, 0, 0, 0)
}

fn prepend_date(dates: List(Date), date: Date) -> List(Date) {
  [date, ..dates]
}

fn parse_dates() -> fn(Parser(List(Date))) ->
  Result(Parser(List(Date)), ParserFailure(InvalidDateError)) {
  pickle.many(create_blank_date(), parse_date(), prepend_date)
}

fn parse_date() -> fn(Parser(Date)) ->
  Result(Parser(Date), ParserFailure(InvalidDateError)) {
  parse_date_year()
  |> pickle.then(parse_date_month())
  |> pickle.then(parse_date_day())
  |> pickle.then(parse_date_hour())
  |> pickle.then(parse_date_minute())
  |> pickle.then(parse_date_second())
}

fn parse_date_year() -> fn(Parser(Date)) ->
  Result(Parser(Date), ParserFailure(InvalidDateError)) {
  pickle.integer(fn(date, year) { Date(..date, year: year) })
  |> pickle.then(pickle.guard(has_valid_year, InvalidYear))
  |> pickle.then(pickle.token("-", pickle.ignore_token))
}

fn parse_date_month() -> fn(Parser(Date)) ->
  Result(Parser(Date), ParserFailure(InvalidDateError)) {
  pickle.integer(fn(date, month) { Date(..date, month: month) })
  |> pickle.then(pickle.guard(has_valid_month, InvalidMonth))
  |> pickle.then(pickle.token("-", pickle.ignore_token))
}

fn parse_date_day() -> fn(Parser(Date)) ->
  Result(Parser(Date), ParserFailure(InvalidDateError)) {
  pickle.integer(fn(date, day) { Date(..date, day: day) })
  |> pickle.then(pickle.guard(has_valid_day, InvalidDay))
  |> pickle.then(pickle.token("T", pickle.ignore_token))
}

fn parse_date_hour() -> fn(Parser(Date)) ->
  Result(Parser(Date), ParserFailure(InvalidDateError)) {
  pickle.integer(fn(date, hour) { Date(..date, hour: hour) })
  |> pickle.then(pickle.guard(has_valid_hour, InvalidHour))
  |> pickle.then(pickle.token(":", pickle.ignore_token))
}

fn parse_date_minute() -> fn(Parser(Date)) ->
  Result(Parser(Date), ParserFailure(InvalidDateError)) {
  pickle.integer(fn(date, minute) { Date(..date, minute: minute) })
  |> pickle.then(pickle.guard(has_valid_minute, InvalidMinute))
  |> pickle.then(pickle.token(":", pickle.ignore_token))
}

fn parse_date_second() -> fn(Parser(Date)) ->
  Result(Parser(Date), ParserFailure(InvalidDateError)) {
  pickle.integer(fn(date, second) { Date(..date, second: second) })
  |> pickle.then(pickle.guard(has_valid_second, InvalidSecond))
  |> pickle.then(pickle.optional(pickle.token("Z", pickle.ignore_token)))
  |> pickle.then(
    pickle.one_of([pickle.token("\n", pickle.ignore_token), pickle.eof()]),
  )
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
