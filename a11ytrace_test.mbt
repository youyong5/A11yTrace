///|
test "reports an image without alt" {
  match @a11ytrace.audit_html("<img src=\"chart.svg\">") {
    Findings(findings) => {
      assert_eq(findings.length(), 1)
      let finding = findings[0]
      assert_eq(finding.rule_id, "img-alt-missing")
      assert_eq(finding.message, "This image has no alt attribute.")
      assert_eq(
        finding.suggestion,
        "Add an alt attribute; use alt=\"\" only when the image is decorative.",
      )
      assert_eq(finding.element_path, "img:nth-of-type(1)")
      assert_eq(finding.line, Some(1))
      assert_eq(finding.column, Some(1))
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "accepts an explicitly decorative image" {
  match @a11ytrace.audit_html("<img src=\"border.svg\" alt=\"\">") {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "accepts an image with non-empty alt text" {
  match @a11ytrace.audit_html("<img src=\"team.jpg\" alt=\"The team\">") {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "reports every missing alt in a group of images" {
  match
    @a11ytrace.audit_html(
      "<img src=\"one.png\"><img src=\"two.png\" alt=\"Two\"><img src=\"three.png\">",
    ) {
    Findings(findings) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].element_path, "img:nth-of-type(1)")
      assert_eq(findings[1].element_path, "img:nth-of-type(3)")
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "uses a stable path for a nested image" {
  match
    @a11ytrace.audit_html(
      "<main><figure><img src=\"chart.png\"></figure></main>",
    ) {
    Findings(findings) => {
      assert_eq(findings.length(), 1)
      assert_eq(
        findings[0].element_path,
        "main:nth-of-type(1) > figure:nth-of-type(1) > img:nth-of-type(1)",
      )
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "keeps findings alongside recoverable parser diagnostics" {
  match @a11ytrace.audit_html("<img src=\"x.png\"></span>") {
    FindingsWithParseErrors(findings, errors) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "img-alt-missing")
      assert_eq(errors.length(), 1)
      assert_eq(errors[0].code, "unexpected-end-tag")
      assert_eq(errors[0].line, Some(1))
      assert_eq(errors[0].column, Some(24))
    }
    Findings(_) => fail("parser diagnostics must not be hidden")
    ParseErrors(_) => fail("recoverable HTML should still be audited")
  }
}
