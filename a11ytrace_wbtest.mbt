///|
test "does not invent a source position when the DOM node has none" {
  let finding = missing_alt_finding(@dom.element("img"), "img:nth-of-type(1)")
  assert_eq(finding.line, None)
  assert_eq(finding.column, None)
}
