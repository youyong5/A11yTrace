///|
test "consumes the public fragment and JSON APIs from another package" {
  match component_audit() {
    Findings(findings) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "button-name-missing")
      assert_eq(findings[0].element_path, "button:nth-of-type(1)")
      let json = @a11ytrace.render_audit_json(Findings(findings))
      assert_true(json.contains("\"button-name-missing\""))
    }
    FindingsWithParseErrors(_, _) =>
      fail("the example fragment should have no parser diagnostics")
    ParseErrors(_) => fail("the example fragment should be audited")
  }
}
