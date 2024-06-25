import pickle.{type ParserResult}
import simplifile
import startest.{describe, it}
import startest/expect

/// CSV Data Format
/// 
/// Invoice No.,Recipient,Total
/// 
/// Int,String,Float
///
/// The parser needs to be able to parse and collect all invoices.
pub fn csv_tests() {
  describe("examples/csv_test/parse_invoices", [
    it(
      "returns all invoices that are part of the invoices.csv file when all invoices are valid",
      fn() {
        let assert Ok(csv_content) =
          simplifile.read("./test/examples/invoices.csv")

        pickle.parse(csv_content, [], parse_invoices)
        |> expect.to_be_ok()
        |> expect.to_equal([
          Invoice(number: 10, recipient: "Jacob", total: 9.99),
          Invoice(number: 8, recipient: "Tim", total: 120.49),
          Invoice(number: 5, recipient: "Maria", total: 29.9),
          Invoice(number: 1, recipient: "John", total: 250.0),
        ])
      },
    ),
  ])
}

type Invoice {
  Invoice(number: Int, recipient: String, total: Float)
}

fn create_blank_invoice() -> Invoice {
  Invoice(0, "", 0.0)
}

fn parse_invoices(
  prev: ParserResult(List(Invoice)),
) -> ParserResult(List(Invoice)) {
  prev
  |> skip_header()
  |> pickle.many(create_blank_invoice(), parse_invoice)
}

fn skip_header(prev: ParserResult(List(Invoice))) -> ParserResult(List(Invoice)) {
  prev |> pickle.skip_until("\n") |> pickle.token("\n", pickle.ignore_token)
}

fn parse_invoice(prev: ParserResult(Invoice)) -> ParserResult(Invoice) {
  prev
  |> parse_invoice_number()
  |> parse_invoice_recipient()
  |> parse_invoice_total()
}

fn parse_invoice_number(prev: ParserResult(Invoice)) -> ParserResult(Invoice) {
  prev
  |> pickle.integer(fn(invoice, number) { Invoice(..invoice, number: number) })
  |> pickle.token(",", pickle.ignore_token)
}

fn parse_invoice_recipient(prev: ParserResult(Invoice)) -> ParserResult(Invoice) {
  prev
  |> pickle.until(",", fn(invoice, recipient) {
    Invoice(..invoice, recipient: recipient)
  })
  |> pickle.token(",", pickle.ignore_token)
}

fn parse_invoice_total(prev: ParserResult(Invoice)) -> ParserResult(Invoice) {
  prev
  |> pickle.float(fn(invoice, total) { Invoice(..invoice, total: total) })
  |> pickle.token("\n", pickle.ignore_token)
}
