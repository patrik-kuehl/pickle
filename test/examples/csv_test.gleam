import gparsec.{type ParserResult}
import simplifile
import startest.{describe, it}
import startest/expect

/// CSV Data Format
/// 
/// Invoice No.;Recipient;Total
/// 
/// Int;String;Int
///
/// The parser needs to be able to parse and collect all invoices.
pub fn csv_tests() {
  describe("examples/csv_test", [
    describe("invoices.csv", [
      it("returns all invoices that are part of the CSV file", fn() {
        let assert Ok(csv_content) =
          simplifile.read("./test/examples/invoices.csv")

        let parser =
          gparsec.input(csv_content, [])
          |> parse_invoices()
          |> expect.to_be_ok()

        parser.value
        |> expect.to_equal([
          Invoice(number: 10, recipient: "Jacob", total: 9),
          Invoice(number: 8, recipient: "Tim", total: 120),
          Invoice(number: 5, recipient: "Maria", total: 29),
          Invoice(number: 1, recipient: "John", total: 250),
        ])
      }),
    ]),
  ])
}

type Invoice {
  Invoice(number: Int, recipient: String, total: Int)
}

fn create_blank_invoice() -> Invoice {
  Invoice(0, "", 0)
}

fn parse_invoices(
  prev: ParserResult(List(Invoice)),
) -> ParserResult(List(Invoice)) {
  prev
  |> skip_header()
  |> gparsec.repeat(create_blank_invoice(), parse_invoice)
}

fn skip_header(prev: ParserResult(List(Invoice))) -> ParserResult(List(Invoice)) {
  prev |> gparsec.skip_until("\n") |> gparsec.token("\n", gparsec.ignore_token)
}

fn parse_invoice(prev: ParserResult(Invoice)) -> ParserResult(Invoice) {
  prev
  |> parse_invoice_number()
  |> parse_invoice_recipient()
  |> parse_invoice_total()
}

fn parse_invoice_number(prev: ParserResult(Invoice)) -> ParserResult(Invoice) {
  prev
  |> gparsec.integer(fn(invoice, number) { Invoice(..invoice, number: number) })
  |> gparsec.token(";", gparsec.ignore_token)
}

fn parse_invoice_recipient(prev: ParserResult(Invoice)) -> ParserResult(Invoice) {
  prev
  |> gparsec.until(";", fn(invoice, recipient) {
    Invoice(..invoice, recipient: recipient)
  })
  |> gparsec.token(";", gparsec.ignore_token)
}

fn parse_invoice_total(prev: ParserResult(Invoice)) -> ParserResult(Invoice) {
  prev
  |> gparsec.integer(fn(invoice, total) { Invoice(..invoice, total: total) })
  |> gparsec.token("\n", gparsec.ignore_token)
}
