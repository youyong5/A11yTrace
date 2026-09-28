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
  let coverage = @a11ytrace.audit_html_with_wcag_coverage(
    "<!doctype html><html lang=\"en\"><head><title>Consumer</title></head><body></body></html>",
  )
  assert_eq(coverage.criteria.length(), 56)
  match @a11ytrace.wcag_criterion("4.1.1") {
    Some(criterion) => assert_true(!criterion.in_wcag22)
    None => fail("consumer should read public WCAG coverage metadata")
  }
  let coverage_json = @a11ytrace.render_wcag_audit_json(coverage)
  assert_true(coverage_json.contains("\"removed_in_wcag22\""))
}
