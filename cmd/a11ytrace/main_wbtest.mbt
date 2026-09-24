///|
test "parses a file format and selected rules" {
  match
    parse_cli_args([
      "page.html", "--format", "json", "--rules", "img-alt-missing, heading-level-skipped",
    ]) {
    Audit({ path, format: Json, rule_ids: Some(rule_ids), }) => {
      assert_eq(path, "page.html")
      assert_eq(rule_ids.length(), 2)
      assert_eq(rule_ids[0], "img-alt-missing")
      assert_eq(rule_ids[1], "heading-level-skipped")
    }
    _ => fail("valid CLI arguments should produce an audit plan")
  }
}

///|
test "parses detailed JSON without changing compatible JSON" {
  match parse_cli_args(["page.html", "--format", "detailed-json"]) {
    Audit({ format: DetailedJson, .. }) => ()
    _ => fail("detailed JSON must be an explicit format")
  }
  match parse_cli_args(["page.html", "--format", "json"]) {
    Audit({ format: Json, .. }) => ()
    _ => fail("the established JSON format must remain available")
  }
}

///|
test "parses help and rejects invalid command lines" {
  assert_true(parse_cli_args(["--help"]) is Help)
  assert_true(parse_cli_args([]) is ArgumentError(_))
  assert_true(
    parse_cli_args(["page.html", "--format", "xml"]) is ArgumentError(_),
  )
  assert_true(
    parse_cli_args(["page.html", "--format", "text", "--format", "text"])
    is ArgumentError(_),
  )
  assert_true(parse_cli_args(["page.html", "--rules"]) is ArgumentError(_))
  assert_true(parse_cli_args(["one.html", "two.html"]) is ArgumentError(_))
}

///|
test "keeps an explicit empty rules selection" {
  match parse_cli_args(["page.html", "--rules", ""]) {
    Audit({ rule_ids: Some(rule_ids), .. }) => assert_eq(rule_ids.length(), 0)
    _ => fail("an empty --rules value must select no rules")
  }
}

///|
test "renders text findings and unknown locations honestly" {
  let result : @a11ytrace_lib.AuditResult = Findings([
    {
      rule_id: "img-alt-missing",
      message: "This image has no alt attribute.",
      suggestion: "Add alt.",
      element_path: "img:nth-of-type(1)",
      line: None,
      column: None,
    },
  ])
  let text = render_text(result)
  assert_true(text.contains("[img-alt-missing]"))
  assert_true(text.contains("location unavailable"))

  let diagnostic_result : @a11ytrace_lib.AuditResult = FindingsWithParseErrors(
    [],
    [
      {
        code: "unexpected-end-tag",
        message: "unexpected-end-tag",
        line: None,
        column: None,
      },
    ],
  )
  let diagnostic_text = render_text(diagnostic_result)
  assert_true(diagnostic_text.contains("Parser diagnostics:"))
  assert_true(diagnostic_text.contains("[unexpected-end-tag]"))
  assert_true(diagnostic_text.contains("location unavailable"))
}
