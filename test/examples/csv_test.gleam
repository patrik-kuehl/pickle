import gleeunit/should
import pickle.{type Parser, type ParserFailure}
import simplifile

/// CSV Data Format
/// 
/// Invoice No.,Recipient,Total
/// 
/// Int,String,Float
///
/// The parser needs to be able to parse and collect all invoices.
pub fn parse_invoices_test() {
  let assert Ok(csv_content) = simplifile.read("./test/examples/invoices.csv")

  pickle.parse(csv_content, [], parse_invoices())
  |> should.be_ok()
  |> should.equal([
    Invoice(number: 10, recipient: "Jacob", total: 9.99),
    Invoice(number: 8, recipient: "Tim", total: 120.49),
    Invoice(number: 5, recipient: "Maria", total: 29.9),
    Invoice(number: 1, recipient: "John", total: 250.0),
  ])
}

type Invoice {
  Invoice(number: Int, recipient: String, total: Float)
}

fn create_blank_invoice() -> Invoice {
  Invoice(0, "", 0.0)
}

fn parse_invoices() -> fn(Parser(List(Invoice))) ->
  Result(Parser(List(Invoice)), ParserFailure(Nil)) {
  skip_header()
  |> pickle.then(pickle.many(
    create_blank_invoice(),
    parse_invoice(),
    pickle.prepend_to_list,
  ))
}

fn skip_header() -> fn(Parser(List(Invoice))) ->
  Result(Parser(List(Invoice)), ParserFailure(Nil)) {
  pickle.skip_until(pickle.string("\n", pickle.drop))
  |> pickle.then(pickle.string("\n", pickle.drop))
}

fn parse_invoice() -> fn(Parser(Invoice)) ->
  Result(Parser(Invoice), ParserFailure(Nil)) {
  parse_invoice_number()
  |> pickle.then(parse_invoice_recipient())
  |> pickle.then(parse_invoice_total())
}

fn parse_invoice_number() -> fn(Parser(Invoice)) ->
  Result(Parser(Invoice), ParserFailure(Nil)) {
  pickle.integer(fn(invoice, number) { Invoice(..invoice, number: number) })
  |> pickle.then(pickle.string(",", pickle.drop))
}

fn parse_invoice_recipient() -> fn(Parser(Invoice)) ->
  Result(Parser(Invoice), ParserFailure(Nil)) {
  pickle.until(
    pickle.string(",", pickle.apppend_to_string),
    fn(invoice, recipient) { Invoice(..invoice, recipient: recipient) },
  )
  |> pickle.then(pickle.string(",", pickle.drop))
}

fn parse_invoice_total() -> fn(Parser(Invoice)) ->
  Result(Parser(Invoice), ParserFailure(Nil)) {
  pickle.float(fn(invoice, total) { Invoice(..invoice, total: total) })
  |> pickle.then(pickle.string("\n", pickle.drop))
}
