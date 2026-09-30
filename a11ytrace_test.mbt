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

///|
test "accepts explicit, wrapping, aria, and title form control names" {
  let html = "<label for=\"email\">Email</label><input id=\"email\">" +
    "<label>Search <input></label>" +
    "<input aria-label=\"Account number\">" +
    "<span id=\"single\">Single label</span><input aria-labelledby=\"single\">" +
    "<span id=\"first\">First</span><span id=\"last\">Last</span>" +
    "<input aria-labelledby=\"first\tlast\">" +
    "<textarea title=\"Notes\"></textarea>"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "reports placeholder-only and empty or invalid label references" {
  let html = "<input placeholder=\"Email\">" +
    "<label for=\"empty\"> </label><input id=\"empty\">" +
    "<input aria-label=\"\">" +
    "<input aria-labelledby=\"missing\">" +
    "<span id=\"blank\"> </span><input aria-labelledby=\"blank\">"
  match @a11ytrace.audit_html_with_rules(html, ["form-control-name-missing"]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 5)
      for finding in findings {
        assert_eq(finding.rule_id, "form-control-name-missing")
      }
      assert_eq(findings[0].element_path, "input:nth-of-type(1)")
      assert_eq(findings[4].element_path, "input:nth-of-type(5)")
    }
    Audited(_) => fail("valid HTML should have no parser diagnostics")
    ConfigurationError(_) => fail("known form rule ID must be accepted")
  }
}

///|
test "does not let unrelated explicit labels name another control" {
  match
    @a11ytrace.audit_html_with_rules(
      "<label for=\"other\">Name <input id=\"name\"></label>",
      ["form-control-name-missing"],
    ) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "form-control-name-missing")
      assert_eq(
        findings[0].element_path,
        "label:nth-of-type(1) > input:nth-of-type(1)",
      )
    }
    Audited(_) => fail("valid HTML should have no parser diagnostics")
    ConfigurationError(_) => fail("known form rule ID must be accepted")
  }
  match
    @a11ytrace.audit_html_with_rules(
      "<label for=\"name\">Name</label><input id=\"other\">",
      ["form-control-name-missing"],
    ) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "form-control-name-missing")
      assert_eq(findings[0].element_path, "input:nth-of-type(1)")
    }
    Audited(_) => fail("valid HTML should have no parser diagnostics")
    ConfigurationError(_) => fail("known form rule ID must be accepted")
  }
}

///|
test "excludes hidden submit and reset inputs" {
  let html = "<input type=\"hidden\"><input type=\"submit\"><input type=\"reset\">"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "reports unnamed select textarea and multiple controls in document order" {
  let html = "<select></select><input aria-label=\"Named\"><textarea></textarea><input>"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].element_path, "select:nth-of-type(1)")
      assert_eq(findings[1].element_path, "textarea:nth-of-type(1)")
      assert_eq(findings[2].element_path, "input:nth-of-type(2)")
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "reports image and form control findings together in document order" {
  match @a11ytrace.audit_html("<img src=\"x.png\"><input>") {
    Findings(findings) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "img-alt-missing")
      assert_eq(findings[1].rule_id, "form-control-name-missing")
      assert_eq(findings[1].line, Some(1))
      assert_eq(findings[1].column, Some(18))
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "accepts link text image alt and explicit name attributes" {
  let html = "<a href=\"/text\"><span>Read more</span></a>" +
    "<a href=\"/image\"><img src=\"cover.png\" alt=\"Book cover\"></a>" +
    "<a href=\"/image-and-text\"><img src=\"icon.png\" alt=\"\"><span>Settings</span></a>" +
    "<a href=\"/aria\" aria-label=\"Profile\"></a>" +
    "<span id=\"downloads\">Downloads</span><a href=\"/files\" aria-labelledby=\"downloads\"></a>" +
    "<a href=\"/help\" title=\"Help centre\"></a>"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "reports empty links and decorative-image-only links" {
  let html = "<a href=\"/\"></a><a href=\"/space\">  </a>" +
    "<a href=\"/decorative\"><img src=\"icon.png\" alt=\"\"></a>"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => {
      assert_eq(findings.length(), 3)
      for finding in findings {
        assert_eq(finding.rule_id, "link-name-missing")
      }
      assert_eq(findings[0].element_path, "a:nth-of-type(1)")
      assert_eq(findings[2].element_path, "a:nth-of-type(3)")
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "does not treat script style or template text as a link name" {
  let html = "<a href=\"/script\"><script>Ignored script text</script></a>" +
    "<a href=\"/style\"><style>.link { color: red; }</style></a>" +
    "<a href=\"/template\"><template>Ignored template text</template></a>"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => {
      assert_eq(findings.length(), 3)
      for finding in findings {
        assert_eq(finding.rule_id, "link-name-missing")
      }
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "detailed fragment audit separates aria hidden focus review items" {
  let result = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(
      "<div aria-hidden=\"true\"><button aria-label=\"Close\"></button></div>",
      ["aria-hidden-focus-review"],
    ) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(value) => value
    _ => fail("known review rule must audit")
  }
  match result.status {
    @a11ytrace.DetailedAuditStatus::Findings => ()
    _ => fail("clean fragment should have findings status")
  }
  assert_eq(result.findings.length(), 0)
  assert_eq(result.parse_diagnostics.length(), 0)
  assert_eq(result.review_items.length(), 1)
  let item = result.review_items[0]
  assert_eq(item.rule_id, "aria-hidden-focus-review")
  assert_eq(item.element_path, "div:nth-of-type(1) > button:nth-of-type(1)")
  assert_eq(item.line, Some(1))
  assert_eq(item.column, Some(25))
}

///|
test "aria hidden ancestors cannot be undone and disabled differs from aria disabled" {
  let html = "<div aria-hidden=\"true\"><div aria-hidden=\"false\">" +
    "<a href=\"/x\">Link</a></div><button disabled aria-label=\"Saved\"></button>" +
    "<button aria-disabled=\"true\" aria-label=\"Unavailable\"></button>" +
    "<div tabindex=\"-1\"></div></div>"
  let result = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(html, [
      "aria-hidden-focus-review",
    ]) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(value) => value
    _ => fail("known review rule must audit")
  }
  assert_eq(result.findings.length(), 0)
  assert_eq(result.review_items.length(), 3)
  assert_eq(
    result.review_items[0].element_path,
    "div:nth-of-type(1) > div:nth-of-type(1) > a:nth-of-type(1)",
  )
  assert_eq(
    result.review_items[1].element_path,
    "div:nth-of-type(1) > button:nth-of-type(2)",
  )
  assert_eq(
    result.review_items[2].element_path,
    "div:nth-of-type(1) > div:nth-of-type(2)",
  )
  assert_true(result.review_items[2].reason.contains("tabindex=\"-1\""))
}

///|
test "detailed rule selection retains reviews and rejects unknown IDs" {
  match
    @a11ytrace.audit_html_fragment_detailed_with_rules(
      "<div aria-hidden=\"true\"><a href=\"/x\">Link</a></div>",
      ["aria-hidden-focus-review", "aria-hidden-focus-review"],
    ) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(result) => {
      assert_eq(result.findings.length(), 0)
      assert_eq(result.review_items.length(), 1)
    }
    _ => fail("detailed selection must retain manual review items")
  }
  match @a11ytrace.audit_html_detailed_with_rules("</span>", ["not-a-rule"]) {
    @a11ytrace.DetailedConfiguredAuditResult::ConfigurationError(
      UnknownRuleId(rule_id)
    ) => assert_eq(rule_id, "not-a-rule")
    _ => fail("unknown detailed rule IDs must be rejected before parsing")
  }
}

///|
test "aria hidden review includes supported native media and summary controls" {
  let result = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(
      "<div aria-hidden=\"true\"><summary>More</summary><video controls></video></div>",
      ["aria-hidden-focus-review"],
    ) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(value) => value
    _ => fail("known review rule must audit")
  }
  assert_eq(result.review_items.length(), 2)
  assert_eq(
    result.review_items[0].element_path,
    "div:nth-of-type(1) > summary:nth-of-type(1)",
  )
  assert_eq(
    result.review_items[1].element_path,
    "div:nth-of-type(1) > video:nth-of-type(1)",
  )
}

///|
test "body aria hidden and multiple main are document-only findings" {
  let document = "<!doctype html><html lang=\"en\"><head><title>Page</title></head>" +
    "<body aria-hidden=\"true\"><main>One</main><main>Two</main></body></html>"
  match
    @a11ytrace.audit_html_with_rules(document, [
      "body-aria-hidden", "multiple-main",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "body-aria-hidden")
      assert_eq(findings[1].rule_id, "multiple-main")
    }
    _ => fail("document-only rules should audit a complete document")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(
      "<body aria-hidden=\"true\"><main></main><main></main>",
      ["body-aria-hidden", "multiple-main"],
    ) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(FindingsWithParseErrors(findings, _)) =>
      assert_eq(findings.length(), 0)
    _ => fail("fragment audit must not run document-only rules")
  }
}

///|
test "multiple navigation landmarks need distinct static names" {
  let valid = "<!doctype html><html lang=\"en\"><head><title>Page</title></head><body>" +
    "<span id=\"footer-name\">Footer</span><nav aria-label=\"Primary\"></nav>" +
    "<nav aria-labelledby=\"footer-name\"></nav></body></html>"
  match
    @a11ytrace.audit_html_with_rules(valid, [
      "navigation-landmark-name-missing", "navigation-landmark-name-duplicate",
    ]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    _ => fail("distinct navigation names should be accepted")
  }
  let invalid = "<!doctype html><html lang=\"en\"><head><title>Page</title></head><body>" +
    "<nav></nav><nav aria-label=\"Primary\"></nav><nav aria-label=\"Primary\"></nav></body></html>"
  match
    @a11ytrace.audit_html_with_rules(invalid, [
      "navigation-landmark-name-missing", "navigation-landmark-name-duplicate",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "navigation-landmark-name-missing")
      assert_eq(findings[1].rule_id, "navigation-landmark-name-duplicate")
    }
    _ => fail("unnamed and duplicate navigation names should be reported")
  }
}

///|
test "svg navigation names are review items and concrete role fallback suppresses abstract tokens" {
  let document = "<!doctype html><html lang=\"en\"><head><title>Page</title></head><body>" +
    "<nav><svg><title>Menu</title></svg></nav><nav aria-label=\"Primary\"></nav>" +
    "<div role=\"button landmark\"></div><div role=\"\"></div></body></html>"
  let detailed = match
    @a11ytrace.audit_html_detailed_with_rules(document, [
      "navigation-landmark-name-missing", "aria-abstract-role",
    ]) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(value) => value
    _ => fail("known rules must audit")
  }
  assert_eq(detailed.review_items.length(), 1)
  assert_eq(
    detailed.review_items[0].rule_id,
    "navigation-landmark-name-missing",
  )
  let abstract_findings = detailed.findings.filter(fn(finding) {
    finding.rule_id == "aria-abstract-role"
  })
  assert_eq(abstract_findings.length(), 0)
  let json = @a11ytrace.render_detailed_audit_json(detailed)
  match @json.parse(json) {
    {
      "status": String(status),
      "review_items": Array([{ "rule_id": String(rule_id), .. }]),
      ..
    } => {
      assert_eq(status, "findings")
      assert_eq(rule_id, "navigation-landmark-name-missing")
    }
    _ => fail("detailed JSON must expose the documented review items")
  }
}

///|
test "abstract role rule covers the complete ARIA 1.2 abstract role set" {
  let html = "<i role=\"command\"></i><i role=\"composite\"></i>" +
    "<i role=\"input\"></i><i role=\"landmark\"></i><i role=\"range\"></i>" +
    "<i role=\"roletype\"></i><i role=\"section\"></i><i role=\"sectionhead\"></i>" +
    "<i role=\"select\"></i><i role=\"structure\"></i><i role=\"widget\"></i>" +
    "<i role=\"window\"></i><i role=\"button\"></i>"
  match @a11ytrace.audit_html_with_rules(html, ["aria-abstract-role"]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 12)
      for finding in findings {
        assert_eq(finding.rule_id, "aria-abstract-role")
      }
    }
    _ =>
      fail(
        "abstract ARIA roles should be identified without rejecting concrete roles",
      )
  }
}

///|
test "detailed JSON round trips diagnostics review reasons and unknown positions" {
  let result : @a11ytrace.DetailedAuditResult = {
    status: @a11ytrace.DetailedAuditStatus::FindingsWithParseErrors,
    findings: [],
    parse_diagnostics: [
      {
        code: "recoverable",
        message: "Bad \"markup\"\n中文",
        line: None,
        column: None,
      },
    ],
    review_items: [
      {
        rule_id: "aria-hidden-focus-review",
        reason: "Check \\ focus and \"CSS\"\n中文",
        element_path: "div:nth-of-type(1)",
        line: None,
        column: None,
      },
    ],
  }
  let json = @a11ytrace.render_detailed_audit_json(result)
  assert_true(@json.valid(json))
  match @json.parse(json) {
    {
      "status": String(status),
      "findings": Array([]),
      "parse_diagnostics": Array(
        [{ "message": String(diagnostic), "line": Null, "column": Null, .. }]
      ),
      "review_items": Array(
        [{ "reason": String(reason), "line": Null, "column": Null, .. }]
      ),
      ..
    } => {
      assert_eq(status, "findings_with_parse_errors")
      assert_eq(diagnostic, "Bad \"markup\"\n中文")
      assert_eq(reason, "Check \\ focus and \"CSS\"\n中文")
    }
    _ => fail("detailed JSON must preserve all result categories")
  }
}

///|
test "detailed audits preserve recoverable parser diagnostics separately" {
  let result = @a11ytrace.audit_html_detailed(
    "<img src=\"missing.png\"></span>",
  )
  match result.status {
    @a11ytrace.DetailedAuditStatus::FindingsWithParseErrors => ()
    _ => fail("recoverable HTML must retain its detailed parser status")
  }
  assert_eq(result.findings.length(), 1)
  assert_eq(result.findings[0].rule_id, "img-alt-missing")
  assert_eq(result.parse_diagnostics.length(), 1)
  assert_eq(result.review_items.length(), 0)
}

///|
test "rule directory exposes stable metadata and copied rule selections" {
  let rules = @a11ytrace.available_rules()
  assert_eq(rules.length(), 79)
  assert_eq(rules[0].id, "img-alt-missing")
  assert_eq(rules[21].id, "meta-refresh-delay")
  assert_eq(rules[22].id, "aria-state-value-invalid")
  assert_eq(rules[23].id, "button-implicit-submit")
  rules[0] = {
    id: "changed",
    summary: "changed",
    category: @a11ytrace.RuleCategory::Aria,
    scope: @a11ytrace.RuleScope::Fragment,
    result_kind: @a11ytrace.RuleResultKind::ManualReview,
    reference_url: "https://example.test/",
    boundary: "changed",
  }
  assert_eq(@a11ytrace.available_rules()[0].id, "img-alt-missing")
  match @a11ytrace.rule_metadata("aria-hidden-focus-review") {
    Some(rule) => {
      assert_eq(
        rule.reference_url,
        "https://www.w3.org/WAI/standards-guidelines/act/rules/6cfa84/",
      )
      assert_true(rule.result_kind is @a11ytrace.RuleResultKind::ManualReview)
      assert_true(rule.scope is @a11ytrace.RuleScope::DocumentOrFragment)
    }
    None => fail("known rule metadata must be available")
  }
  match @a11ytrace.rule_metadata("aria-range-value-invalid") {
    Some(rule) => {
      assert_true(
        rule.result_kind is @a11ytrace.RuleResultKind::ConfirmedFinding,
      )
      assert_true(rule.scope is @a11ytrace.RuleScope::DocumentOrFragment)
      assert_eq(
        rule.reference_url,
        "https://www.w3.org/TR/wai-aria-1.2/#aria-valuenow",
      )
    }
    None => fail("range-value metadata must be available")
  }
  match @a11ytrace.rule_metadata("label-for-target-not-labelable") {
    Some(rule) => {
      assert_true(
        rule.result_kind is @a11ytrace.RuleResultKind::ConfirmedFinding,
      )
      assert_true(rule.scope is @a11ytrace.RuleScope::DocumentOrFragment)
    }
    None => fail("label-target metadata must be available")
  }
  match @a11ytrace.rule_metadata("label-multiple-labelable-descendants") {
    Some(rule) => {
      assert_true(
        rule.result_kind is @a11ytrace.RuleResultKind::ConfirmedFinding,
      )
      assert_true(rule.scope is @a11ytrace.RuleScope::DocumentOrFragment)
    }
    None => fail("multiple-label metadata must be available")
  }
  match @a11ytrace.rule_metadata("aria-role-attribute-incompatible") {
    Some(rule) => {
      assert_true(rule.category is @a11ytrace.RuleCategory::Aria)
      assert_true(rule.scope is @a11ytrace.RuleScope::DocumentOrFragment)
      assert_true(
        rule.result_kind is @a11ytrace.RuleResultKind::ConfirmedFinding,
      )
    }
    None => fail("role attribute compatibility metadata must be available")
  }
  match @a11ytrace.rule_metadata("html-lang-invalid") {
    Some(rule) => {
      assert_true(rule.category is @a11ytrace.RuleCategory::DocumentStructure)
      assert_true(rule.scope is @a11ytrace.RuleScope::Document)
      assert_true(
        rule.result_kind is @a11ytrace.RuleResultKind::ConfirmedFinding,
      )
    }
    None => fail("document language metadata must be available")
  }
  match @a11ytrace.rule_metadata("element-lang-invalid") {
    Some(rule) => {
      assert_true(rule.scope is @a11ytrace.RuleScope::DocumentOrFragment)
      assert_true(
        rule.result_kind is @a11ytrace.RuleResultKind::ConfirmedFinding,
      )
    }
    None => fail("content language metadata must be available")
  }
  assert_true(@a11ytrace.rule_metadata("not-a-rule") is None)
  let content_ids = @a11ytrace.content_rule_ids()
  assert_true(content_ids.contains("img-alt-missing"))
  assert_true(!content_ids.contains("document-title-missing"))
  let document_ids = @a11ytrace.document_rule_ids()
  assert_true(document_ids.contains("document-title-missing"))
  assert_true(document_ids.contains("meta-refresh-delay"))
  assert_true(@a11ytrace.review_rule_ids().contains("aria-hidden-focus-review"))
  assert_true(@a11ytrace.review_rule_ids().contains("target-size-review"))
  match @a11ytrace.rule_metadata("role-value-invalid") {
    Some(rule) => {
      assert_true(rule.category is @a11ytrace.RuleCategory::Aria)
      assert_true(rule.scope is @a11ytrace.RuleScope::DocumentOrFragment)
      assert_true(
        rule.result_kind is @a11ytrace.RuleResultKind::ConfirmedFinding,
      )
    }
    None => fail("new ARIA metadata must be available")
  }
  match @a11ytrace.rule_metadata("role-button-name-missing") {
    Some(rule) => {
      assert_true(rule.category is @a11ytrace.RuleCategory::ContentName)
      assert_true(rule.scope is @a11ytrace.RuleScope::DocumentOrFragment)
      assert_true(
        rule.result_kind is @a11ytrace.RuleResultKind::ConfirmedFinding,
      )
    }
    None => fail("custom role name metadata must be available")
  }
  match @a11ytrace.rule_metadata("role-radio-name-missing") {
    Some(rule) => {
      assert_true(rule.category is @a11ytrace.RuleCategory::ContentName)
      assert_true(rule.scope is @a11ytrace.RuleScope::DocumentOrFragment)
      assert_true(
        rule.result_kind is @a11ytrace.RuleResultKind::ConfirmedFinding,
      )
    }
    None => fail("custom radio name metadata must be available")
  }
  match @a11ytrace.rule_metadata("role-textbox-name-missing") {
    Some(rule) => {
      assert_true(rule.category is @a11ytrace.RuleCategory::ContentName)
      assert_true(rule.scope is @a11ytrace.RuleScope::DocumentOrFragment)
      assert_true(
        rule.result_kind is @a11ytrace.RuleResultKind::ConfirmedFinding,
      )
    }
    None => fail("custom text-input name metadata must be available")
  }
}

///|
test "reports supported nonzero meta refresh delays in complete documents only" {
  let page = "<!doctype html><html lang=\"en\"><head><title>Page</title>" +
    "<meta http-equiv=\"REFRESH\" content=\" 5;url=/next\">" +
    "<meta http-equiv=\"refresh\" content=\".5\">" +
    "<meta http-equiv=\"refresh\" content=\"0;url=/next\">" +
    "<meta http-equiv=\"refresh\" content=\"00.0\">" +
    "<meta http-equiv=\"refresh\" content=\"five\"></head><body></body></html>"
  match @a11ytrace.audit_html_with_rules(page, ["meta-refresh-delay"]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "meta-refresh-delay")
      assert_eq(findings[1].rule_id, "meta-refresh-delay")
    }
    _ => fail("supported nonzero document refresh delays should be reported")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(
      "<meta http-equiv=\"refresh\" content=\"5\">",
      ["meta-refresh-delay"],
    ) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    _ => fail("fragment audit must not run page timing rules")
  }
}

///|
test "checks only documented ARIA state token types" {
  let html = "<button aria-expanded=\" TRUE \" aria-pressed=\"mixed\"></button>" +
    "<span aria-current=\"PAGE\" aria-invalid=\"grammar\"></span>" +
    "<div aria-hidden=\"undefined\" aria-checked=\"undefined\"></div>" +
    "<div aria-expanded=\"yes\"></div><div aria-checked=\"maybe\"></div>" +
    "<div aria-current=\"later\"></div>"
  match @a11ytrace.audit_html_with_rules(html, ["aria-state-value-invalid"]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 3)
      for finding in findings {
        assert_eq(finding.rule_id, "aria-state-value-invalid")
      }
    }
    _ => fail("invalid values for selected ARIA states should be reported")
  }
}

///|
test "suggests explicit button types only for missing or empty form buttons" {
  let html = "<form><button>Save</button><button type=\"\">Cancel</button>" +
    "<button type=\"submit\">Submit</button><button type=\"button\">Preview</button></form>" +
    "<button>Outside</button>"
  match @a11ytrace.audit_html_with_rules(html, ["button-implicit-submit"]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(
        findings[0].element_path,
        "form:nth-of-type(1) > button:nth-of-type(1)",
      )
      assert_eq(
        findings[1].element_path,
        "form:nth-of-type(1) > button:nth-of-type(2)",
      )
    }
    _ =>
      fail(
        "only implicit form submit buttons should receive a best-practice prompt",
      )
  }
}

///|
test "does not audit anchors without href and conservatively skips svg links" {
  match
    @a11ytrace.audit_html(
      "<a>Not a link</a><a href=\"/icon\"><svg></svg></a>" +
      "<a href=\"/named\" aria-label=\"Menu\"><svg></svg></a>" +
      "<a href=\"/text\"><svg></svg>Help</a>",
    ) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "keeps image form and link findings in document order" {
  match
    @a11ytrace.audit_html("<img src=\"x.png\"><input><a href=\"/empty\"></a>") {
    Findings(findings) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].rule_id, "img-alt-missing")
      assert_eq(findings[1].rule_id, "form-control-name-missing")
      assert_eq(findings[2].rule_id, "link-name-missing")
      assert_eq(findings[2].line, Some(1))
      assert_eq(findings[2].column, Some(25))
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "accepts named native buttons" {
  let html = "<button>Save</button>" +
    "<button><img src=\"save.png\" alt=\"Save\"></button>" +
    "<button><img src=\"gear.png\" alt=\"\"><span>Settings</span></button>" +
    "<button aria-label=\"Close\"></button>" +
    "<span id=\"menu-label\">Menu</span><button aria-labelledby=\"menu-label\"></button>" +
    "<button title=\"Help\"></button>"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "reports empty and decorative-image-only native buttons" {
  match
    @a11ytrace.audit_html(
      "<button> </button><button><img src=\"icon.png\" alt=\"\"></button>",
    ) {
    Findings(findings) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "button-name-missing")
      assert_eq(findings[1].rule_id, "button-name-missing")
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "uses non-empty value aria and title for input buttons" {
  let html = "<input type=\"button\" value=\"Save\">" +
    "<input type=\"button\" aria-label=\"Close\">" +
    "<input type=\"button\" title=\"Help\">" +
    "<input type=\"button\" value=\"\">"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "button-name-missing")
      assert_eq(findings[0].element_path, "input:nth-of-type(4)")
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "checks image inputs and excludes submit and reset inputs" {
  let html = "<input type=\"image\" alt=\"Search\">" +
    "<input type=\"image\" aria-label=\"Upload\">" +
    "<input type=\"image\">" +
    "<input type=\"submit\"><input type=\"reset\">"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "button-name-missing")
      assert_eq(findings[0].element_path, "input:nth-of-type(3)")
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "conservatively skips svg-only native buttons" {
  match
    @a11ytrace.audit_html(
      "<button><svg></svg></button><button aria-label=\"Menu\"><svg></svg></button>",
    ) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "does not use inactive text or type case to bypass button checks" {
  let html = "<button><script>Ignored</script></button>" +
    "<button><style>.x { display: none; }</style></button>" +
    "<button><template>Ignored</template></button>" +
    "<input type=\"BUTTON\" value=\"\">" +
    "<input type=\"ImAgE\">"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => {
      assert_eq(findings.length(), 5)
      for finding in findings {
        assert_eq(finding.rule_id, "button-name-missing")
      }
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "keeps all four rule findings in document order" {
  let html = "<img src=\"x.png\"><input><a href=\"/empty\"></a><button></button>"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => {
      assert_eq(findings.length(), 4)
      assert_eq(findings[0].rule_id, "img-alt-missing")
      assert_eq(findings[1].rule_id, "form-control-name-missing")
      assert_eq(findings[2].rule_id, "link-name-missing")
      assert_eq(findings[3].rule_id, "button-name-missing")
      assert_eq(findings[3].line, Some(1))
      assert_eq(findings[3].column, Some(46))
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "only reports downward native heading level skips" {
  match
    @a11ytrace.audit_html(
      "<h3>First heading</h3><h2>Back up</h2><h2>Same</h2><h3>One down</h3>",
    ) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
  match @a11ytrace.audit_html("<h2>Section</h2><h4>Nested section</h4>") {
    Findings(findings) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "heading-level-skipped")
      assert_eq(findings[0].element_path, "h4:nth-of-type(1)")
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "recognizes heading text aria and image alt names" {
  let html = "<h1>Title</h1><h2 aria-label=\"Overview\"></h2>" +
    "<span id=\"status\">Status</span><h3 aria-labelledby=\"status\"></h3>" +
    "<h4><img src=\"chart.png\" alt=\"Sales chart\"></h4>"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "reports empty headings and ignores template headings" {
  match
    @a11ytrace.audit_html("<h1> </h1><h2><img src=\"icon.png\" alt=\"\"></h2>") {
    Findings(findings) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "heading-name-missing")
      assert_eq(findings[1].rule_id, "heading-name-missing")
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
  match
    @a11ytrace.audit_html(
      "<h2>Visible</h2><template><h4>Template only</h4></template><h3>Next</h3>",
    ) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "does not use inactive descendant text for heading names" {
  let html = "<h1><script>Ignored</script></h1>" +
    "<h2><style>.heading { color: red; }</style></h2>" +
    "<h3><template>Ignored</template></h3>"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].rule_id, "heading-name-missing")
      assert_eq(findings[1].rule_id, "heading-name-missing")
      assert_eq(findings[2].rule_id, "heading-name-missing")
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "keeps all rules and heading findings in document order" {
  let html = "<img src=\"x.png\"><input><a href=\"/empty\"></a><button></button>" +
    "<h2>Section</h2><h4></h4>"
  match @a11ytrace.audit_html(html) {
    Findings(findings) => {
      assert_eq(findings.length(), 6)
      assert_eq(findings[0].rule_id, "img-alt-missing")
      assert_eq(findings[1].rule_id, "form-control-name-missing")
      assert_eq(findings[2].rule_id, "link-name-missing")
      assert_eq(findings[3].rule_id, "button-name-missing")
      assert_eq(findings[4].rule_id, "heading-level-skipped")
      assert_eq(findings[5].rule_id, "heading-name-missing")
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "lists rule IDs and keeps the default audit behavior" {
  let rule_ids = @a11ytrace.available_rule_ids()
  assert_eq(rule_ids.length(), 79)
  assert_eq(rule_ids[0], "img-alt-missing")
  assert_eq(rule_ids[4], "heading-level-skipped")
  assert_eq(rule_ids[5], "heading-name-missing")
  assert_eq(rule_ids[6], "document-title-missing")
  assert_eq(rule_ids[9], "duplicate-id")
  assert_eq(rule_ids[10], "reference-target-invalid")
  assert_eq(rule_ids[14], "area-alt-missing")
  assert_eq(rule_ids[15], "aria-hidden-focus-review")
  assert_eq(rule_ids[20], "aria-abstract-role")
  assert_eq(rule_ids[21], "meta-refresh-delay")
  assert_eq(rule_ids[22], "aria-state-value-invalid")
  assert_eq(rule_ids[23], "button-implicit-submit")
  assert_true(rule_ids.contains("aria-attribute-undefined"))
  assert_true(rule_ids.contains("role-value-invalid"))
  assert_true(rule_ids.contains("table-scope-invalid"))
  assert_true(rule_ids.contains("role-button-name-missing"))
  assert_true(rule_ids.contains("role-link-name-missing"))
  assert_true(rule_ids.contains("role-radio-name-missing"))
  assert_true(rule_ids.contains("role-textbox-name-missing"))
  assert_true(rule_ids.contains("role-searchbox-name-missing"))
  assert_true(rule_ids.contains("aria-range-value-invalid"))
  assert_true(rule_ids.contains("label-for-target-not-labelable"))
  assert_true(rule_ids.contains("label-multiple-labelable-descendants"))
  assert_true(rule_ids.contains("aria-checked-role-incompatible"))
  assert_true(rule_ids.contains("listitem-orphan"))
  assert_true(rule_ids.contains("fieldset-legend-missing"))
  assert_true(rule_ids.contains("aria-role-attribute-incompatible"))
  assert_true(rule_ids.contains("html-lang-invalid"))
  assert_true(rule_ids.contains("element-lang-invalid"))
  rule_ids[0] = "not-a-rule"
  let fresh_rule_ids = @a11ytrace.available_rule_ids()
  assert_eq(fresh_rule_ids[0], "img-alt-missing")
  let html = "<img src=\"x.png\"><input>"
  match @a11ytrace.audit_html(html) {
    Findings(default_findings) =>
      match @a11ytrace.audit_html_with_rules(html, fresh_rule_ids) {
        Audited(Findings(configured_findings)) => {
          assert_eq(configured_findings.length(), default_findings.length())
          assert_eq(configured_findings[0].rule_id, "img-alt-missing")
          assert_eq(configured_findings[1].rule_id, "form-control-name-missing")
        }
        Audited(_) =>
          fail("valid HTML should have findings without diagnostics")
        ConfigurationError(_) => fail("known rule IDs must be accepted")
      }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "WCAG coverage catalog is version aware and does not claim a pass" {
  let criteria = @a11ytrace.wcag_aa_criteria()
  assert_eq(criteria.length(), 56)
  assert_eq(
    criteria
    .filter(fn(item) {
      item.coverage_status is @a11ytrace.WcagCoverageStatus::PartialAutomatic
    })
    .length(),
    10,
  )
  assert_eq(
    criteria
    .filter(fn(item) {
      item.coverage_status is @a11ytrace.WcagCoverageStatus::ManualReview
    })
    .length(),
    32,
  )
  assert_eq(
    criteria
    .filter(fn(item) {
      item.coverage_status is @a11ytrace.WcagCoverageStatus::NotAssessed
    })
    .length(),
    13,
  )
  assert_eq(
    criteria
    .filter(fn(item) {
      item.coverage_status is @a11ytrace.WcagCoverageStatus::RemovedInWcag22
    })
    .length(),
    1,
  )
  match @a11ytrace.wcag_criterion("4.1.1") {
    Some(criterion) => {
      assert_true(criterion.in_wcag21)
      assert_true(!criterion.in_wcag22)
      assert_true(
        criterion.coverage_status
        is @a11ytrace.WcagCoverageStatus::RemovedInWcag22,
      )
    }
    None => fail("historical parsing criterion must be documented")
  }
  match @a11ytrace.wcag_criterion("2.4.11") {
    Some(criterion) => {
      assert_true(criterion.in_wcag22)
      assert_true(criterion.level is @a11ytrace.WcagLevel::AA)
      assert_true(
        criterion.coverage_status is @a11ytrace.WcagCoverageStatus::ManualReview,
      )
    }
    None => fail("WCAG 2.2 AA addition must be documented")
  }
  match @a11ytrace.wcag_criterion("3.1.2") {
    Some(criterion) => {
      assert_true(
        criterion.coverage_status
        is @a11ytrace.WcagCoverageStatus::PartialAutomatic,
      )
      assert_true(criterion.rule_ids.contains("element-lang-invalid"))
    }
    None => fail("language-of-parts coverage must retain its partial boundary")
  }
  let result = @a11ytrace.audit_html_with_wcag_coverage("<p>Clean-looking</p>")
  assert_eq(result.audit.findings.length(), 0)
  assert_eq(result.criteria.length(), 56)
  match @json.parse(@a11ytrace.render_wcag_audit_json(result)) {
    {
      "audit": { "findings": Array([]), "review_items": Array(_), .. },
      "criteria": Array([{ "id": String(first_id), .. }, ..]),
      ..
    } => assert_eq(first_id, "1.1.1")
    _ => fail("coverage JSON must retain detailed audit and criterion records")
  }
}

///|
test "checks selected ARIA roles, names, required properties, and ID references" {
  let html = "<div role=\"checkbox\"></div><div role=\"combobox\" aria-expanded=\"false\" aria-label=\"Search\"></div>" +
    "<div role=\"slider\" aria-label=\"Volume\"></div><div role=\"heading\" aria-level=\"3\">Topic</div>" +
    "<div role=\"tab\" aria-selected=\"false\">One</div><div role=\"switch\" aria-checked=\"true\">Dark</div>" +
    "<div aria-controls=\"missing\"></div><div id=\"target\"></div><div aria-controls=\"target\"></div>"
  match
    @a11ytrace.audit_html_with_rules(html, [
      "aria-required-property-missing", "aria-idref-invalid", "role-checkbox-name-missing",
      "role-combobox-name-missing", "role-slider-name-missing", "role-heading-level-missing",
      "role-tab-selected-missing", "role-switch-checked-missing",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 4)
      assert_eq(findings[0].rule_id, "aria-required-property-missing")
      assert_eq(findings[1].rule_id, "role-checkbox-name-missing")
      assert_eq(findings[2].rule_id, "aria-required-property-missing")
      assert_eq(findings[3].rule_id, "aria-idref-invalid")
    }
    _ => fail("selected ARIA rules should audit valid fragment parsing")
  }
}

///|
test "checks structural rules without treating inert template contents as input" {
  let html = "<a href=\"/x\"><button>Go</button></a><ul><div>Bad</div><li>Good</li></ul>" +
    "<dl><p>Bad</p><dt>Term</dt><dd>Meaning</dd></dl><table><th></th></table>" +
    "<template><ul><div>Ignored</div></ul></template>"
  let structure_result = @a11ytrace.audit_html_with_rules(html, [
    "nested-interactive", "list-structure-invalid", "definition-list-structure-invalid",
    "table-header-name-missing",
  ])
  let findings = match structure_result {
    Audited(Findings(items)) => items
    Audited(FindingsWithParseErrors(items, _)) => items
    _ => fail("structural checks should produce an auditable recovered DOM")
  }
  assert_eq(findings.length(), 4)
  assert_eq(findings[0].rule_id, "nested-interactive")
  assert_eq(findings[1].rule_id, "list-structure-invalid")
  assert_eq(findings[2].rule_id, "definition-list-structure-invalid")
  assert_eq(findings[3].rule_id, "table-header-name-missing")
  match
    @a11ytrace.audit_html_with_rules(
      "<!doctype html><html><head><meta name=\"viewport\" content=\"maximum-scale=1\"></head><body></body></html>",
      ["viewport-zoom-disabled"],
    ) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 1)
    _ => fail("zoom-disabling viewport token should be a document hint")
  }
}

///|
test "detailed review rules locate static risk markers without claiming findings" {
  let html = "<video autoplay></video><div role=\"button\" tabindex=\"0\" accesskey=\"x\"></div>" +
    "<div draggable onpointerdown=\"go()\" ondevicemotion=\"move()\"></div>" +
    "<form><input type=\"password\" onchange=\"go()\"></form>"
  let result = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(html, [
      "media-alternative-review", "media-autoplay-audio-review", "keyboard-operation-review",
      "character-key-shortcut-review", "focus-order-review", "focus-visible-review",
      "focus-obscured-review", "target-size-review", "dragging-movement-review",
      "pointer-cancellation-review", "motion-actuation-review", "form-error-review",
      "authentication-review", "on-input-context-review",
    ]) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(value) => value
    _ => fail("known review rules should audit")
  }
  assert_eq(result.findings.length(), 0)
  assert_eq(result.review_items.length(), 14)
  assert_eq(result.review_items[0].rule_id, "media-alternative-review")
  assert_eq(result.review_items[1].rule_id, "media-autoplay-audio-review")
  assert_true(
    result.review_items.any(fn(item) { item.rule_id == "authentication-review" }),
  )
}

///|
test "ARIA role-name rules cover author names and conservative role image handling" {
  let unnamed = "<div role=\"checkbox\"></div><div role=\"combobox\"></div>" +
    "<div role=\"slider\"></div><div role=\"progressbar\"></div>" +
    "<div role=\"meter\"></div><div role=\"img\">Plain text is not its name</div>" +
    "<div role=\"dialog\"></div>"
  let selected = [
    "role-checkbox-name-missing", "role-combobox-name-missing", "role-slider-name-missing",
    "role-progressbar-name-missing", "role-meter-name-missing", "role-img-name-missing",
    "role-dialog-name-missing",
  ]
  match @a11ytrace.audit_html_fragment_with_rules(unnamed, selected) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 7)
    _ => fail("every selected unnamed ARIA role should be reported")
  }
  let named = "<div role=\"checkbox\" aria-label=\"Accept\"></div>" +
    "<span id=\"combo-name\">Search</span><div role=\"combobox\" aria-labelledby=\"combo-name\"></div>" +
    "<div role=\"slider\" title=\"Volume\"></div><div role=\"progressbar\" aria-label=\"Loading\"></div>" +
    "<div role=\"meter\" title=\"Score\"></div><div role=\"img\" aria-label=\"Map\">plain</div>" +
    "<div role=\"alertdialog\" title=\"Warning\"></div>"
  match @a11ytrace.audit_html_fragment_with_rules(named, selected) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    _ => fail("supported author names should suppress selected role findings")
  }
  let svg = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(
      "<div role=\"img\"><svg><title>Chart</title></svg></div>",
      ["role-img-name-missing"],
    ) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(result) => result
    _ => fail("known role rule should audit")
  }
  assert_eq(svg.findings.length(), 0)
  assert_eq(svg.review_items.length(), 1)
}

///|
test "selected ARIA required-state rules distinguish missing and valid values" {
  let selected = [
    "aria-required-property-missing", "role-heading-level-missing", "role-tab-selected-missing",
    "role-switch-checked-missing",
  ]
  let missing = "<div role=\"combobox\"></div><div role=\"heading\">Topic</div>" +
    "<div role=\"tab\">One</div><div role=\"switch\"></div>"
  match @a11ytrace.audit_html_fragment_with_rules(missing, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 5)
      assert_eq(findings[0].rule_id, "aria-required-property-missing")
      assert_eq(findings[1].rule_id, "role-heading-level-missing")
      assert_eq(findings[2].rule_id, "role-tab-selected-missing")
      assert_eq(findings[3].rule_id, "aria-required-property-missing")
      assert_eq(findings[4].rule_id, "role-switch-checked-missing")
    }
    _ => fail("missing selected ARIA states should report")
  }
  let valid = "<div role=\"combobox\" aria-expanded=\"false\"></div>" +
    "<div role=\"heading\" aria-level=\"6\">Topic</div><div role=\"tab\" aria-selected=\"false\">One</div>" +
    "<div role=\"switch\" aria-checked=\"mixed\">On</div>"
  match @a11ytrace.audit_html_fragment_with_rules(valid, selected) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    _ => fail("valid selected ARIA states should not report")
  }
}

///|
test "extended references and viewport check handle valid tokens and document scope" {
  let selected = ["aria-idref-invalid", "aria-required-property-missing"]
  let html = "<div id=\"one\"></div><div id=\"two\"></div>" +
    "<div aria-controls=\"one two\"></div><div aria-owns=\"missing one\"></div>" +
    "<div role=\"checkbox\" aria-checked=\"false\"></div><div role=\"slider\" aria-valuenow=\"0\"></div>"
  match @a11ytrace.audit_html_fragment_with_rules(html, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "aria-idref-invalid")
    }
    _ => fail("only the mixed invalid IDREF list should report")
  }
  let document = "<!doctype html><html><head>" +
    "<meta name=\"viewport\" content=\"maximum-scale=10\">" +
    "<meta name=\"viewport\" content=\"maximum-scale=1.5\">" +
    "</head><body></body></html>"
  match @a11ytrace.audit_html_with_rules(document, ["viewport-zoom-disabled"]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(
        findings[0].element_path,
        "html:nth-of-type(1) > head:nth-of-type(1) > meta:nth-of-type(2)",
      )
    }
    _ => fail("only a maximum scale below two should report")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(
      "<meta name=\"viewport\" content=\"user-scalable=no\">",
      ["viewport-zoom-disabled"],
    ) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(FindingsWithParseErrors(findings, _)) =>
      assert_eq(findings.length(), 0)
    _ => fail("viewport rule must not run for fragments")
  }
}

///|
test "detailed JSON labels review-only output as needing review" {
  let result = match
    @a11ytrace.audit_html_fragment_detailed_with_rules("<video></video>", [
      "media-alternative-review",
    ]) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(value) => value
    _ => fail("known review rule should audit")
  }
  assert_eq(result.findings.length(), 0)
  assert_eq(result.review_items.length(), 1)
  match @json.parse(@a11ytrace.render_detailed_audit_json(result)) {
    {
      "assessment": String(assessment),
      "findings": Array([]),
      "review_items": Array([_, ..]),
      ..
    } => assert_eq(assessment, "needs_review")
    _ => fail("review-only detailed JSON must not look like a pass")
  }
}

///|
test "remaining review markers have specific triggers and clean markup has none" {
  let page = "<!doctype html><html lang=\"en\"><head><title>Review</title></head><body>" +
    "<div role=\"dialog\" aria-label=\"Settings\"></div><button aria-label=\"Save\" onfocus=\"go()\">Save</button>" +
    "<div lang=\"fr\">Bonjour</div><div role=\"status\"></div><p>Text</p></body></html>"
  let selected = [
    "keyboard-trap-review", "label-in-name-review", "language-of-parts-review", "on-focus-context-review",
    "status-message-review", "bypass-blocks-review", "meaningful-sequence-review",
    "contrast-review", "text-resize-review",
  ]
  let result = match @a11ytrace.audit_html_detailed_with_rules(page, selected) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(value) => value
    _ => fail("known review rules should audit a document")
  }
  assert_eq(result.findings.length(), 0)
  assert_eq(result.review_items.length(), 11)
  assert_true(
    result.review_items.any(fn(item) { item.rule_id == "keyboard-trap-review" }),
  )
  assert_true(
    result.review_items.any(fn(item) { item.rule_id == "bypass-blocks-review" }),
  )
  let clean = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(
      "<div>Plain content</div>", selected,
    ) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(value) => value
    _ => fail("known review rules should audit a fragment")
  }
  assert_eq(clean.review_items.length(), 0)
}

///|
test "new ARIA checks retain findings and reviews with recoverable parser diagnostics" {
  let result = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(
      "<div role=\"checkbox\"></div><video></video></span>",
      [
        "aria-required-property-missing", "role-checkbox-name-missing", "media-alternative-review",
      ],
    ) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(value) => value
    _ => fail("known rules should audit recovered markup")
  }
  assert_true(
    result.status is @a11ytrace.DetailedAuditStatus::FindingsWithParseErrors,
  )
  assert_eq(result.findings.length(), 2)
  assert_eq(result.review_items.length(), 1)
  assert_eq(result.parse_diagnostics.length(), 1)
}

///|
test "audits only selected rules without changing the caller selection" {
  let selected_rule_ids = ["form-control-name-missing"]
  match
    @a11ytrace.audit_html_with_rules(
      "<img src=\"x.png\"><input><button></button>", selected_rule_ids,
    ) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "form-control-name-missing")
    }
    Audited(_) => fail("valid HTML should have findings without diagnostics")
    ConfigurationError(_) => fail("known rule IDs must be accepted")
  }
  assert_eq(selected_rule_ids.length(), 1)
  assert_eq(selected_rule_ids[0], "form-control-name-missing")
}

///|
test "deduplicates selected rules and preserves document order" {
  let selected_rule_ids = [
    "heading-name-missing", "img-alt-missing", "button-name-missing", "img-alt-missing",
  ]
  match
    @a11ytrace.audit_html_with_rules(
      "<button></button><h2></h2><img src=\"x.png\">", selected_rule_ids,
    ) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].rule_id, "button-name-missing")
      assert_eq(findings[1].rule_id, "heading-name-missing")
      assert_eq(findings[2].rule_id, "img-alt-missing")
    }
    Audited(_) => fail("valid HTML should have findings without diagnostics")
    ConfigurationError(_) => fail("known rule IDs must be accepted")
  }
  assert_eq(selected_rule_ids.length(), 4)
  assert_eq(selected_rule_ids[3], "img-alt-missing")
}

///|
test "keeps parser diagnostics when the selected rule list is empty" {
  match @a11ytrace.audit_html_with_rules("<img src=\"x.png\"></span>", []) {
    Audited(FindingsWithParseErrors(findings, errors)) => {
      assert_eq(findings.length(), 0)
      assert_eq(errors.length(), 1)
      assert_eq(errors[0].code, "unexpected-end-tag")
    }
    Audited(_) => fail("recoverable HTML diagnostics must be preserved")
    ConfigurationError(_) => fail("an empty selection is valid")
  }
}

///|
test "keeps default findings with recoverable parser diagnostics" {
  let html = "<img src=\"x.png\"></span>"
  match @a11ytrace.audit_html(html) {
    FindingsWithParseErrors(default_findings, default_errors) =>
      match
        @a11ytrace.audit_html_with_rules(html, @a11ytrace.available_rule_ids()) {
        Audited(FindingsWithParseErrors(configured_findings, configured_errors)) => {
          assert_eq(configured_findings.length(), default_findings.length())
          assert_eq(configured_findings[0].rule_id, "img-alt-missing")
          assert_eq(configured_errors.length(), default_errors.length())
          assert_eq(configured_errors[0].code, "unexpected-end-tag")
        }
        Audited(_) => fail("recoverable diagnostics must be preserved")
        ConfigurationError(_) => fail("known rule IDs must be accepted")
      }
    Findings(_) => fail("recoverable HTML must retain diagnostics")
    ParseErrors(_) => fail("recoverable HTML should be audited")
  }
}

///|
test "reports an unknown selected rule ID as a configuration error" {
  match @a11ytrace.audit_html_with_rules("</span>", ["not-a-rule"]) {
    ConfigurationError(UnknownRuleId(rule_id)) =>
      assert_eq(rule_id, "not-a-rule")
    Audited(_) => fail("unknown rule IDs must not be ignored")
  }
}

///|
test "renders an empty audit result as parseable JSON" {
  let json = @a11ytrace.render_audit_json(
    @a11ytrace.audit_html("<img src=\"logo.svg\" alt=\"Logo\">"),
  )
  assert_true(@json.valid(json))
  match @json.parse(json) {
    {
      "status": String(status),
      "findings": Array(findings),
      "parse_diagnostics": Array(diagnostics),
      ..
    } => {
      assert_eq(status, "findings")
      assert_eq(findings.length(), 0)
      assert_eq(diagnostics.length(), 0)
    }
    _ => fail("JSON result must have the documented fields")
  }
}

///|
test "renders multiple findings with parser source positions" {
  let json = @a11ytrace.render_audit_json(
    @a11ytrace.audit_html("<img src=\"one.png\"><input>"),
  )
  match @json.parse(json) {
    {
      "status": String(status),
      "findings": Array([first, second]),
      "parse_diagnostics": Array([]),
      ..
    } => {
      assert_eq(status, "findings")
      match first {
        {
          "rule_id": String(rule_id),
          "element_path": String(path),
          "line": Number(line, ..),
          "column": Number(column, ..),
          ..
        } => {
          assert_eq(rule_id, "img-alt-missing")
          assert_eq(path, "img:nth-of-type(1)")
          assert_eq(line, 1.0)
          assert_eq(column, 1.0)
        }
        _ => fail("the first finding must expose its public fields")
      }
      match second {
        { "rule_id": String(rule_id), .. } =>
          assert_eq(rule_id, "form-control-name-missing")
        _ => fail("the second finding must expose its rule ID")
      }
    }
    _ => fail("JSON result must preserve multiple findings")
  }
}

///|
test "renders unknown positions and special characters safely" {
  let result : @a11ytrace.AuditResult = Findings([
    {
      rule_id: "custom \"rule\" 名称\n",
      message: "Line one\nLine two with \\ and \"quotes\"",
      suggestion: "使用 Unicode：✓",
      element_path: "custom:nth-of-type(1)",
      line: None,
      column: None,
    },
  ])
  let json = @a11ytrace.render_audit_json(result)
  assert_true(@json.valid(json))
  match @json.parse(json) {
    {
      "findings": Array(
        [
          {
            "rule_id": String(rule_id),
            "message": String(message),
            "suggestion": String(suggestion),
            "line": Null,
            "column": Null,
            ..
          },
        ]
      ),
      ..
    } => {
      assert_eq(rule_id, "custom \"rule\" 名称\n")
      assert_eq(message, "Line one\nLine two with \\ and \"quotes\"")
      assert_eq(suggestion, "使用 Unicode：✓")
    }
    _ => fail("JSON strings must round-trip through the standard parser")
  }
}

///|
test "renders recoverable parser diagnostics distinctly" {
  let json = @a11ytrace.render_audit_json(
    @a11ytrace.audit_html("<img src=\"x.png\"></span>"),
  )
  match @json.parse(json) {
    {
      "status": String(status),
      "findings": Array([finding]),
      "parse_diagnostics": Array([diagnostic]),
      ..
    } => {
      assert_eq(status, "findings_with_parse_errors")
      match finding {
        { "rule_id": String(rule_id), .. } =>
          assert_eq(rule_id, "img-alt-missing")
        _ => fail("recoverable HTML must retain its finding")
      }
      match diagnostic {
        {
          "code": String(code),
          "line": Number(line, ..),
          "column": Number(column, ..),
          ..
        } => {
          assert_eq(code, "unexpected-end-tag")
          assert_eq(line, 1.0)
          assert_eq(column, 24.0)
        }
        _ => fail("recoverable HTML must expose its parser diagnostic")
      }
    }
    _ => fail("recoverable diagnostics need their own JSON status")
  }
}

///|
test "renders parser failures distinctly" {
  let result : @a11ytrace.AuditResult = ParseErrors([
    {
      code: "parser-failure",
      message: "No DOM available",
      line: None,
      column: None,
    },
  ])
  let json = @a11ytrace.render_audit_json(result)
  match @json.parse(json) {
    {
      "status": String(status),
      "findings": Array([]),
      "parse_diagnostics": Array(
        [{ "code": String(code), "line": Null, "column": Null, .. }]
      ),
      ..
    } => {
      assert_eq(status, "parse_errors")
      assert_eq(code, "parser-failure")
    }
    _ => fail("parser failures need their own JSON status")
  }
}

///|
test "audits a single button fragment with its source position" {
  match @a11ytrace.audit_html_fragment("<button></button>") {
    Findings(findings) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "button-name-missing")
      assert_eq(findings[0].element_path, "button:nth-of-type(1)")
      assert_eq(findings[0].line, Some(1))
      assert_eq(findings[0].column, Some(1))
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid fragments should have no parser diagnostics")
    ParseErrors(_) => fail("valid fragments should be audited")
  }
}

///|
test "keeps mixed fragment findings in source order and selects rules" {
  let fragment = "<img src=\"x.png\">\n<input>\n<a href=\"/details\"></a>"
  match @a11ytrace.audit_html_fragment(fragment) {
    Findings(findings) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].rule_id, "img-alt-missing")
      assert_eq(findings[0].line, Some(1))
      assert_eq(findings[1].rule_id, "form-control-name-missing")
      assert_eq(findings[1].line, Some(2))
      assert_eq(findings[2].rule_id, "link-name-missing")
      assert_eq(findings[2].line, Some(3))
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid fragments should have no parser diagnostics")
    ParseErrors(_) => fail("valid fragments should be audited")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(fragment, ["link-name-missing"]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "link-name-missing")
    }
    Audited(_) => fail("valid fragments should have no parser diagnostics")
    ConfigurationError(_) => fail("known rule IDs must be accepted")
  }
}

///|
test "keeps fragment references local to the supplied markup" {
  let document = "<label for=\"email\">Email</label><input id=\"email\">"
  match @a11ytrace.audit_html(document) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid document input should have no parser diagnostics")
    ParseErrors(_) => fail("valid document input should be audited")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules("<input id=\"email\">", [
      "form-control-name-missing",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "form-control-name-missing")
    }
    Audited(_) => fail("valid fragments should have no parser diagnostics")
    ConfigurationError(_) => fail("known form rule ID must be accepted")
  }
  match
    @a11ytrace.audit_html_fragment(
      "<label for=\"email\">Email</label><input id=\"email\">",
    ) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid fragments should have no parser diagnostics")
    ParseErrors(_) => fail("valid fragments should be audited")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(
      "<input aria-labelledby=\"name\">",
      ["form-control-name-missing"],
    ) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "form-control-name-missing")
    }
    Audited(_) => fail("valid fragments should have no parser diagnostics")
    ConfigurationError(_) => fail("known form rule ID must be accepted")
  }
  match
    @a11ytrace.audit_html_fragment(
      "<span id=\"name\">Name</span><input aria-labelledby=\"name\">",
    ) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid fragments should have no parser diagnostics")
    ParseErrors(_) => fail("valid fragments should be audited")
  }
}

///|
test "preserves fragment parser diagnostics and configuration errors" {
  match @a11ytrace.audit_html_fragment("<img src=\"x.png\"></span>") {
    FindingsWithParseErrors(findings, errors) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "img-alt-missing")
      assert_eq(errors.length(), 1)
      assert_eq(errors[0].code, "unexpected-end-tag")
    }
    Findings(_) => fail("fragment parser diagnostics must not be hidden")
    ParseErrors(_) => fail("recoverable fragments should be audited")
  }
  match @a11ytrace.audit_html_fragment_with_rules("</span>", ["not-a-rule"]) {
    ConfigurationError(UnknownRuleId(rule_id)) =>
      assert_eq(rule_id, "not-a-rule")
    Audited(_) => fail("unknown fragment rule IDs must not be ignored")
  }
}

///|
test "keeps heading fragment semantics for first headings and templates" {
  let fragment = "<h3>First</h3><template><h6>Template only</h6></template><h4>Next</h4>"
  match @a11ytrace.audit_html_fragment(fragment) {
    Findings(findings) => assert_eq(findings.length(), 0)
    FindingsWithParseErrors(_, _) =>
      fail("valid fragments should have no parser diagnostics")
    ParseErrors(_) => fail("valid fragments should be audited")
  }
}

///|
test "reports missing document title and language only for complete documents" {
  let document = "<!doctype html><html><head><title> </title></head><body></body></html>"
  match
    @a11ytrace.audit_html_with_rules(document, [
      "document-title-missing", "html-lang-missing",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "html-lang-missing")
      assert_eq(findings[0].element_path, "html:nth-of-type(1)")
      assert_eq(findings[1].rule_id, "document-title-missing")
      assert_eq(
        findings[1].element_path,
        "html:nth-of-type(1) > head:nth-of-type(1) > title:nth-of-type(1)",
      )
    }
    Audited(_) => fail("a complete document should have the two page findings")
    ConfigurationError(_) => fail("known page rule IDs must be accepted")
  }
  let valid = "<!doctype html><html lang=\"en\"><head><title>Example</title></head><body></body></html>"
  match
    @a11ytrace.audit_html_with_rules(valid, [
      "document-title-missing", "html-lang-missing",
    ]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) =>
      fail("valid complete document should not have parser diagnostics")
    ConfigurationError(_) => fail("known page rule IDs must be accepted")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules("<title></title>", [
      "document-title-missing", "html-lang-missing",
    ]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("the simple fragment should have no parser diagnostics")
    ConfigurationError(_) => fail("known page rule IDs must be accepted")
  }
}

///|
test "reports a missing title at html when no title element exists" {
  let document = "<!doctype html><html lang=\"en\"><head></head><body></body></html>"
  match @a11ytrace.audit_html_with_rules(document, ["document-title-missing"]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].element_path, "html:nth-of-type(1)")
      assert_eq(findings[0].line, Some(1))
    }
    Audited(_) => fail("missing title should be reported")
    ConfigurationError(_) => fail("known page rule ID must be accepted")
  }
}

///|
test "recognizes supported iframe names and reports missing or unresolved names" {
  let named = "<span id=\"frame-label\">Report</span>" +
    "<iframe title=\"Map\"></iframe>" +
    "<iframe aria-label=\"Calendar\"></iframe>" +
    "<iframe aria-labelledby=\"frame-label\"></iframe>"
  match
    @a11ytrace.audit_html_fragment_with_rules(named, ["iframe-name-missing"]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("named iframes should have no parser diagnostics")
    ConfigurationError(_) => fail("known iframe rule ID must be accepted")
  }
  let unnamed = "<iframe></iframe><iframe title=\" \"></iframe>" +
    "<iframe aria-labelledby=\"missing\"></iframe>"
  match
    @a11ytrace.audit_html_fragment_with_rules(unnamed, ["iframe-name-missing"]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].element_path, "iframe:nth-of-type(1)")
      assert_eq(findings[2].element_path, "iframe:nth-of-type(3)")
    }
    Audited(_) =>
      fail("valid iframe fragments should have no parser diagnostics")
    ConfigurationError(_) => fail("known iframe rule ID must be accepted")
  }
}

///|
test "indexes duplicate IDs once and keeps ambiguous references unnamed" {
  let fragment = "<span id=\"label\">Name</span><span id=\"label\">Again</span>" +
    "<input aria-labelledby=\"label\">"
  match
    @a11ytrace.audit_html_fragment_with_rules(fragment, [
      "duplicate-id", "form-control-name-missing",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "duplicate-id")
      assert_eq(findings[0].element_path, "span:nth-of-type(2)")
      assert_eq(findings[1].rule_id, "form-control-name-missing")
    }
    Audited(_) => fail("valid fragments should have no parser diagnostics")
    ConfigurationError(_) => fail("known rule IDs must be accepted")
  }
  let templates_are_not_input_scope = "<template><span id=\"same\">Template</span></template><div id=\"same\"></div>"
  match
    @a11ytrace.audit_html_fragment_with_rules(templates_are_not_input_scope, [
      "duplicate-id",
    ]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("valid fragments should have no parser diagnostics")
    ConfigurationError(_) => fail("known rule ID must be accepted")
  }
}

///|
test "shares indexed label and IDREF handling for multiple missing and cyclic references" {
  let labelled = "<label for=\"email\">Email</label><input id=\"email\" aria-labelledby=\"missing helper\">" +
    "<span id=\"helper\">Help</span>"
  match
    @a11ytrace.audit_html_fragment_with_rules(labelled, [
      "form-control-name-missing",
    ]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("valid fragments should have no parser diagnostics")
    ConfigurationError(_) => fail("known rule ID must be accepted")
  }
  let cyclic = "<span id=\"first\" aria-labelledby=\"second\"></span>" +
    "<span id=\"second\" aria-labelledby=\"first\"></span>" +
    "<input aria-labelledby=\"first second\">"
  match
    @a11ytrace.audit_html_fragment_with_rules(cyclic, [
      "form-control-name-missing",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "form-control-name-missing")
    }
    Audited(_) => fail("valid fragments should have no parser diagnostics")
    ConfigurationError(_) => fail("known rule ID must be accepted")
  }
}

///|
test "keeps document parser diagnostics with iframe findings" {
  let document = "<!doctype html><html lang=\"en\"><head><title>Example</title></head>" +
    "<body><iframe></iframe></span></body></html>"
  match @a11ytrace.audit_html_with_rules(document, ["iframe-name-missing"]) {
    Audited(FindingsWithParseErrors(findings, diagnostics)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "iframe-name-missing")
      assert_true(diagnostics.length() > 0)
    }
    Audited(_) =>
      fail("recoverable document HTML must retain the iframe finding")
    ConfigurationError(_) => fail("known iframe rule ID must be accepted")
  }
}

///|
test "keeps existing rule findings on a complete document with page metadata" {
  let document = "<!doctype html><html lang=\"en\"><head><title>Example</title></head><body>" +
    "<img src=\"chart.png\"><input><a href=\"/next\"></a><button></button>" +
    "<h2>Section</h2><h4></h4></body></html>"
  match @a11ytrace.audit_html(document) {
    Findings(findings) => {
      assert_eq(findings.length(), 6)
      assert_eq(findings[0].rule_id, "img-alt-missing")
      assert_eq(findings[1].rule_id, "form-control-name-missing")
      assert_eq(findings[2].rule_id, "link-name-missing")
      assert_eq(findings[3].rule_id, "button-name-missing")
      assert_eq(findings[4].rule_id, "heading-level-skipped")
      assert_eq(findings[5].rule_id, "heading-name-missing")
    }
    FindingsWithParseErrors(_, _) =>
      fail("the complete document should not have parser diagnostics")
    ParseErrors(_) => fail("the complete document should be audited")
  }
}

///|
test "distinguishes IDREF target existence from static name text" {
  let fragment = "<span id=\"hidden-name\" hidden aria-hidden=\"true\">Hidden name</span>" +
    "<input aria-labelledby=\"hidden-name\">" +
    "<input aria-labelledby=\"missing hidden-name\">" +
    "<input id=\"self\" aria-labelledby=\"self\">" +
    "<span id=\"first\" aria-labelledby=\"second\"></span>" +
    "<span id=\"second\" aria-labelledby=\"first\"></span>" +
    "<input aria-labelledby=\"first second\">"
  match
    @a11ytrace.audit_html_fragment_with_rules(fragment, [
      "form-control-name-missing",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].element_path, "input:nth-of-type(3)")
      assert_eq(findings[1].element_path, "input:nth-of-type(4)")
    }
    Audited(_) => fail("the fragment should not have parser diagnostics")
    ConfigurationError(_) => fail("known name rule must be accepted")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(fragment, [
      "reference-target-invalid",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].element_path, "input:nth-of-type(2)")
    }
    Audited(_) => fail("the fragment should not have parser diagnostics")
    ConfigurationError(_) => fail("known reference rule must be accepted")
  }
}

///|
test "reports invalid label and ARIA references without claiming names are missing" {
  let fragment = "<label for=\"missing-control\">Name</label>" +
    "<span id=\"valid-label\">Valid label</span>" +
    "<input aria-label=\"Email\" aria-labelledby=\"valid-label missing-label\">" +
    "<span id=\"description\"></span>" +
    "<div aria-describedby=\"description missing-description\"></div>" +
    "<div aria-labelledby=\"\"></div><div aria-describedby=\" \"></div>"
  match
    @a11ytrace.audit_html_fragment_with_rules(fragment, [
      "reference-target-invalid", "form-control-name-missing",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].rule_id, "reference-target-invalid")
      assert_eq(findings[0].element_path, "label:nth-of-type(1)")
      assert_eq(findings[1].rule_id, "reference-target-invalid")
      assert_eq(findings[1].element_path, "input:nth-of-type(1)")
      assert_eq(findings[2].element_path, "div:nth-of-type(1)")
    }
    Audited(_) => fail("the fragment should not have parser diagnostics")
    ConfigurationError(_) => fail("known rules must be accepted")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(
      "<span id=\"same\">One</span><span id=\"same\">Two</span><input aria-labelledby=\"same\">",
      ["duplicate-id", "reference-target-invalid"],
    ) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "duplicate-id")
      assert_eq(findings[1].rule_id, "reference-target-invalid")
    }
    Audited(_) => fail("the fragment should not have parser diagnostics")
    ConfigurationError(_) => fail("known rules must be accepted")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(
      "<input aria-describedby=\"outside\">",
      ["reference-target-invalid"],
    ) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 1)
    Audited(_) => fail("the fragment should not have parser diagnostics")
    ConfigurationError(_) => fail("known rule must be accepted")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(
      "<input id=\"control\"><label for=\"control\" aria-describedby=\"missing\">Control</label>",
      ["reference-target-invalid"],
    ) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].element_path, "label:nth-of-type(1)")
    }
    Audited(_) => fail("the fragment should not have parser diagnostics")
    ConfigurationError(_) => fail("known rule must be accepted")
  }
}

///|
test "label for reports only unique known built-in targets that are not labelable" {
  let selected = ["label-for-target-not-labelable", "reference-target-invalid"]
  let invalid = "<div id=\"plain\"></div><input id=\"secret\" type=\"hidden\">" +
    "<label for=\"plain\">Plain</label><label for=\"secret\">Secret</label>"
  match @a11ytrace.audit_html_fragment_with_rules(invalid, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "label-for-target-not-labelable")
      assert_eq(findings[0].element_path, "label:nth-of-type(1)")
      assert_eq(findings[1].rule_id, "label-for-target-not-labelable")
      assert_eq(findings[1].element_path, "label:nth-of-type(2)")
    }
    Audited(_) => fail("unique non-labelable built-in targets must report")
    ConfigurationError(_) => fail("the label target rule must be selectable")
  }
  let valid = "<button id=\"button\"></button><input id=\"input\">" +
    "<meter id=\"meter\"></meter><output id=\"output\"></output>" +
    "<progress id=\"progress\"></progress><select id=\"select\"></select>" +
    "<textarea id=\"textarea\"></textarea>" +
    "<label for=\"button\">Button</label><label for=\"input\">Input</label>" +
    "<label for=\"meter\">Meter</label><label for=\"output\">Output</label>" +
    "<label for=\"progress\">Progress</label><label for=\"select\">Select</label>" +
    "<label for=\"textarea\">Textarea</label>"
  match @a11ytrace.audit_html_fragment_with_rules(valid, selected) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("labelable built-in targets must not report")
    ConfigurationError(_) => fail("the label target rule must be selectable")
  }
}

///|
test "label for keeps missing duplicate and custom targets conservative" {
  let selected = [
    "label-for-target-not-labelable", "reference-target-invalid", "duplicate-id",
  ]
  let markup = "<label for=\"missing\">Missing</label>" +
    "<div id=\"duplicate\"></div><div id=\"duplicate\"></div>" +
    "<label for=\"duplicate\">Duplicate</label>" +
    "<my-control id=\"custom\"></my-control><label for=\"custom\">Custom</label>"
  match @a11ytrace.audit_html_fragment_with_rules(markup, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].rule_id, "reference-target-invalid")
      assert_eq(findings[1].rule_id, "duplicate-id")
      assert_eq(findings[2].rule_id, "reference-target-invalid")
    }
    Audited(_) => fail("invalid ID targets must remain owned by existing rules")
    ConfigurationError(_) => fail("known label relationship rules must audit")
  }
  match
    @a11ytrace.audit_html_with_rules(
      "<!doctype html><html><body><div id=\"plain\"></div><label for=\"plain\">Plain</label></body></html>",
      ["label-for-target-not-labelable"],
    ) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 1)
    Audited(_) =>
      fail("the relationship rule must also audit complete documents")
    ConfigurationError(_) => fail("the label target rule must be selectable")
  }
}

///|
test "label reports multiple known labelable descendants only once" {
  let selected = ["label-multiple-labelable-descendants"]
  let markup = "<label>First <input><select></select></label>" +
    "<label for=\"chosen\">Chosen <input id=\"chosen\"><textarea></textarea></label>" +
    "<label><input type=\"hidden\"><meter></meter><output></output></label>"
  match @a11ytrace.audit_html_fragment_with_rules(markup, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].rule_id, "label-multiple-labelable-descendants")
      assert_eq(findings[0].element_path, "label:nth-of-type(1)")
      assert_eq(findings[1].rule_id, "label-multiple-labelable-descendants")
      assert_eq(findings[1].element_path, "label:nth-of-type(2)")
      assert_eq(findings[2].rule_id, "label-multiple-labelable-descendants")
      assert_eq(findings[2].element_path, "label:nth-of-type(3)")
    }
    Audited(_) => fail("each invalid label must report exactly once")
    ConfigurationError(_) =>
      fail("the multiple-labelable rule must be selectable")
  }
}

///|
test "label multiple-descendant rule accepts one control and skips custom or template content" {
  let selected = ["label-multiple-labelable-descendants"]
  let valid = "<input id=\"shared\"><label for=\"shared\">First</label><label for=\"shared\">Second</label>" +
    "<label>One <input></label><label><input type=\"hidden\"><textarea></textarea></label>" +
    "<label><my-control></my-control><another-control></another-control></label>" +
    "<label><input><template><select></select></template></label>"
  match @a11ytrace.audit_html_fragment_with_rules(valid, selected) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) =>
      fail("one built-in control and uncertain custom content must not report")
    ConfigurationError(_) =>
      fail("the multiple-labelable rule must be selectable")
  }
  let document = "<!doctype html><html><body><label><button></button><progress></progress></label></body></html>"
  let result = match @a11ytrace.audit_html_with_rules(document, selected) {
    Audited(result) => result
    ConfigurationError(_) =>
      fail("the multiple-labelable rule must audit documents")
  }
  match result {
    Findings(findings) => {
      assert_eq(findings.length(), 1)
      match @json.parse(@a11ytrace.render_audit_json(result)) {
        { "findings": Array([{ "rule_id": String(rule_id), .. }]), .. } =>
          assert_eq(rule_id, "label-multiple-labelable-descendants")
        _ =>
          fail(
            "existing audit JSON must retain the label content-model finding",
          )
      }
    }
    _ => fail("valid document syntax must retain its content-model finding")
  }
}

///|
test "checks each table headers token against other cells in the same table" {
  let valid = "<table><tr><td id=\"blank\"></td><th id=\"column\" headers=\"blank\">Column</th>" +
    "<td headers=\"blank column\">Value</td><td headers=\"\">No explicit headers</td></tr></table>"
  match
    @a11ytrace.audit_html_fragment_with_rules(valid, ["table-headers-invalid"]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("the table fragment should not have parser diagnostics")
    ConfigurationError(_) => fail("known table rule must be accepted")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(
      "<td headers=\"missing\">Outside a table</td>",
      ["table-headers-invalid"],
    ) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(FindingsWithParseErrors(findings, diagnostics)) => {
      assert_eq(findings.length(), 0)
      assert_true(diagnostics.length() > 0)
    }
    Audited(ParseErrors(_)) => fail("recoverable fragment should be audited")
    ConfigurationError(_) => fail("known table rule must be accepted")
  }
  let invalid = "<table><tr><td id=\"self\" headers=\"self\">Self</td>" +
    "<td headers=\"missing\">Missing</td><td id=\"dup\"></td><th id=\"dup\"></th>" +
    "<td headers=\"dup\">Ambiguous</td><td headers=\"outside\">" +
    "<table><tr><td id=\"outside\">Nested</td></tr></table></td></tr></table>"
  match
    @a11ytrace.audit_html_fragment_with_rules(invalid, [
      "duplicate-id", "table-headers-invalid",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 5)
      assert_eq(findings[0].rule_id, "table-headers-invalid")
      assert_eq(findings[1].rule_id, "table-headers-invalid")
      assert_eq(findings[2].rule_id, "duplicate-id")
      assert_eq(findings[3].rule_id, "table-headers-invalid")
      assert_eq(findings[4].rule_id, "table-headers-invalid")
    }
    Audited(_) => fail("the table fragment should not have parser diagnostics")
    ConfigurationError(_) => fail("known table rules must be accepted")
  }
}

///|
test "reports clickable image map areas without non-empty alt text" {
  let fragment = "<map name=\"planets\"><area href=\"sun.html\" alt=\"Sun\">" +
    "<area href=\"moon.html\" alt=\"\"><area href=\"mars.html\">" +
    "<area alt=\"No link\"></map>"
  match
    @a11ytrace.audit_html_fragment_with_rules(fragment, ["area-alt-missing"]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(
        findings[0].element_path,
        "map:nth-of-type(1) > area:nth-of-type(2)",
      )
      assert_eq(
        findings[1].element_path,
        "map:nth-of-type(1) > area:nth-of-type(3)",
      )
    }
    Audited(_) => fail("the map fragment should not have parser diagnostics")
    ConfigurationError(_) => fail("known area rule must be accepted")
  }
}

///|
test "accepts WAI-ARIA 1.2 attribute names and reports unsupported aria attributes" {
  let valid = "<div ARIA-LABEL=\"Name\" aria-description=\"Help\"" +
    " aria-braillelabel=\"Braille\" aria-brailleroledescription=\"control\"" +
    " aria-colindextext=\"C\" aria-rowindextext=\"R\"" +
    " aria-dropeffect=\"move\" aria-grabbed=\"false\"" +
    " data-aria-future=\"not-aria\"></div>"
  match
    @a11ytrace.audit_html_fragment_with_rules(valid, [
      "aria-attribute-undefined",
    ]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("legal WAI-ARIA 1.2 attribute names must not report")
    ConfigurationError(_) => fail("known ARIA attribute rule must be accepted")
  }
  let invalid = "<div aria-future-state=\"x\"></div>" +
    "<span aria-label=\"Known\" aria-not-defined=\"x\"></span>" +
    "<template><p aria-template-only=\"x\"></p></template>"
  match
    @a11ytrace.audit_html_fragment_with_rules(invalid, [
      "aria-attribute-undefined",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].element_path, "div:nth-of-type(1)")
      assert_eq(findings[1].element_path, "span:nth-of-type(1)")
      for finding in findings {
        assert_eq(finding.rule_id, "aria-attribute-undefined")
      }
    }
    Audited(_) => fail("unsupported aria-* names outside templates must report")
    ConfigurationError(_) => fail("known ARIA attribute rule must be accepted")
  }
  let document = "<!doctype html><html lang=\"en\"><head><title>Page</title></head>" +
    "<body><div aria-not-real=\"x\"></div></body></html>"
  match
    @a11ytrace.audit_html_with_rules(document, ["aria-attribute-undefined"]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 1)
    Audited(_) => fail("the ARIA attribute rule must also apply to documents")
    ConfigurationError(_) => fail("known ARIA attribute rule must be accepted")
  }
}

///|
test "uses ordered concrete role fallback without duplicate abstract or invalid role reports" {
  let fragment = "<div role=\"made-up button\"></div>" +
    "<div role=\"widget checkbox\"></div>" +
    "<div role=\"widget\"></div>" +
    "<div role=\"made-up other\"></div>" +
    "<div role=\"presentation\"></div><div role=\"MADE-UP BUTTON\"></div>"
  let selected = [
    "role-value-invalid", "aria-abstract-role", "aria-required-property-missing",
  ]
  match @a11ytrace.audit_html_fragment_with_rules(fragment, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].rule_id, "aria-required-property-missing")
      assert_eq(findings[0].element_path, "div:nth-of-type(2)")
      assert_eq(findings[1].rule_id, "aria-abstract-role")
      assert_eq(findings[1].element_path, "div:nth-of-type(3)")
      assert_eq(findings[2].rule_id, "role-value-invalid")
      assert_eq(findings[2].element_path, "div:nth-of-type(4)")
    }
    Audited(_) => fail("role fallback behavior must preserve distinct findings")
    ConfigurationError(_) => fail("known role rules must be accepted")
  }
  let document = "<!doctype html><html lang=\"en\"><head><title>Page</title></head>" +
    "<body><div role=\"unknown-role\"></div></body></html>"
  match @a11ytrace.audit_html_with_rules(document, ["role-value-invalid"]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 1)
    Audited(_) => fail("the role value rule must also apply to documents")
    ConfigurationError(_) => fail("known role rule must be accepted")
  }
}

///|
test "checks only explicit invalid table header scope values" {
  let valid = "<table><tr><th>Implicit</th><th scope=\"ROW\">Row</th>" +
    "<th scope=\"colgroup\">Group</th><td scope=\"sideways\">Data</td></tr></table>"
  match
    @a11ytrace.audit_html_fragment_with_rules(valid, ["table-scope-invalid"]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("missing and valid th scope values must not report")
    ConfigurationError(_) => fail("known table scope rule must be accepted")
  }
  let invalid = "<table><tr><th scope=\"sideways\">Bad</th><th scope=\"\">Empty</th>" +
    "<td headers=\"missing\">Cell</td></tr></table>" +
    "<template><table><tr><th scope=\"template-only\"></th></tr></table></template>"
  match
    @a11ytrace.audit_html_fragment_with_rules(invalid, [
      "table-scope-invalid", "table-headers-invalid",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].rule_id, "table-scope-invalid")
      assert_eq(findings[1].rule_id, "table-scope-invalid")
      assert_eq(findings[2].rule_id, "table-headers-invalid")
    }
    Audited(_) =>
      fail("invalid explicit scopes must coexist with table IDREF findings")
    ConfigurationError(_) => fail("known table rules must be accepted")
  }
  let document = "<!doctype html><html lang=\"en\"><head><title>Page</title></head>" +
    "<body><table><tr><th scope=\"diagonal\">Bad</th></tr></table></body></html>"
  match @a11ytrace.audit_html_with_rules(document, ["table-scope-invalid"]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 1)
    Audited(_) => fail("the table scope rule must also apply to documents")
    ConfigurationError(_) => fail("known table scope rule must be accepted")
  }
}

///|
test "new ARIA and table findings survive recoverable parser diagnostics" {
  let fragment = "<div aria-future-state=\"x\"></div><table><tr>" +
    "<th scope=\"bad\">Header</th></tr></table></span>"
  match
    @a11ytrace.audit_html_fragment_with_rules(fragment, [
      "aria-attribute-undefined", "table-scope-invalid",
    ]) {
    Audited(FindingsWithParseErrors(findings, diagnostics)) => {
      assert_eq(findings.length(), 2)
      assert_true(diagnostics.length() > 0)
      assert_eq(findings[0].rule_id, "aria-attribute-undefined")
      assert_eq(findings[1].rule_id, "table-scope-invalid")
    }
    Audited(_) =>
      fail("recoverable markup must retain new findings and diagnostics")
    ConfigurationError(_) => fail("known new rules must be accepted")
  }
}

///|
test "shared labelledby target sources name native and selected ARIA controls" {
  let fragment = "<span id=\"author-name\" aria-label=\"Shared name\"></span>" +
    "<input aria-labelledby=\"author-name\">" +
    "<a href=\"/details\" aria-labelledby=\"author-name\"></a>" +
    "<button aria-labelledby=\"author-name\"></button>" +
    "<input type=\"button\" aria-labelledby=\"author-name\">" +
    "<input type=\"image\" aria-labelledby=\"author-name\">" +
    "<iframe aria-labelledby=\"author-name\"></iframe>" +
    "<h2 aria-labelledby=\"author-name\"></h2>" +
    "<div role=\"checkbox\" aria-checked=\"true\" aria-labelledby=\"author-name\"></div>" +
    "<img src=\"still-needs-alt.png\" aria-labelledby=\"author-name\">"
  let selected = [
    "form-control-name-missing", "link-name-missing", "button-name-missing", "iframe-name-missing",
    "heading-name-missing", "role-checkbox-name-missing", "img-alt-missing",
  ]
  match @a11ytrace.audit_html_fragment_with_rules(fragment, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "img-alt-missing")
    }
    Audited(_) =>
      fail("shared static labelledby sources must name all supported consumers")
    ConfigurationError(_) => fail("known name rules must be accepted")
  }
}

///|
test "labelledby preserves IDREF order, self labels, and aria-label fallback for static landmarks" {
  let document = "<!doctype html><html lang=\"en\"><head><title>Page</title></head><body>" +
    "<span id=\"first\">First</span><span id=\"second\">Second</span>" +
    "<span id=\"file\">File</span><span id=\"empty\"></span>" +
    "<nav aria-label=\"Fallback\" aria-labelledby=\"first second\"></nav>" +
    "<nav aria-label=\"Fallback\" aria-labelledby=\"second first\"></nav>" +
    "<nav id=\"self-first\" aria-label=\"Self\" aria-labelledby=\"self-first file\"></nav>" +
    "<nav id=\"self-second\" aria-label=\"Self\" aria-labelledby=\"file self-second\"></nav>" +
    "<nav aria-label=\"Fallback\" aria-labelledby=\"missing empty\"></nav>" +
    "</body></html>"
  match
    @a11ytrace.audit_html_with_rules(document, [
      "navigation-landmark-name-missing", "navigation-landmark-name-duplicate",
    ]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) =>
      fail(
        "ordered valid IDREFs must outrank aria-label and empty or missing targets must fall back",
      )
    ConfigurationError(_) => fail("known landmark rules must be accepted")
  }
}

///|
test "labelledby self references and cycles use bounded static target computation" {
  let fragment = "<span id=\"file\">Report</span>" +
    "<button id=\"delete\" aria-label=\"Delete\" aria-labelledby=\"delete file\"></button>" +
    "<span id=\"first\" aria-labelledby=\"second\"></span>" +
    "<span id=\"second\" aria-labelledby=\"first\"></span>" +
    "<a href=\"/cycle\" aria-labelledby=\"first\"></a>" +
    "<input aria-label=\"Fallback\" aria-labelledby=\"missing empty\">" +
    "<span id=\"empty\"></span>"
  match
    @a11ytrace.audit_html_fragment_with_rules(fragment, [
      "button-name-missing", "link-name-missing", "form-control-name-missing",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "link-name-missing")
      assert_eq(findings[0].element_path, "a:nth-of-type(1)")
    }
    Audited(_) =>
      fail(
        "cycles must not invent static names and valid fallbacks must remain usable",
      )
    ConfigurationError(_) => fail("known name rules must be accepted")
  }
}

///|
test "custom button and link roles accept the shared static name sources" {
  let fragment = "<span id=\"shared\" aria-label=\"Shared name\"></span>" +
    "<div role=\"button\">Save</div>" +
    "<span role=\"link\"><img src=\"guide.svg\" alt=\"Guide\"></span>" +
    "<div role=\"future-role button\" aria-labelledby=\"shared\"></div>" +
    "<span role=\"link\" aria-label=\"Profile\"></span>" +
    "<span role=\"link\" title=\"Settings\"></span>"
  let selected = ["role-button-name-missing", "role-link-name-missing"]
  match @a11ytrace.audit_html_fragment_with_rules(fragment, selected) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("supported static custom-role names must not report")
    ConfigurationError(_) =>
      fail("known custom role name rules must be accepted")
  }
  let invalid = "<div role=\"button\"> </div>" +
    "<span role=\"link\"><img src=\"decorative.svg\" alt=\"\"></span>" +
    "<div role=\"future-role button\"></div>" +
    "<span role=\"link\"><template><img alt=\"Template only\"></template></span>"
  match @a11ytrace.audit_html_fragment_with_rules(invalid, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 4)
      assert_eq(findings[0].rule_id, "role-button-name-missing")
      assert_eq(findings[1].rule_id, "role-link-name-missing")
      assert_eq(findings[2].rule_id, "role-button-name-missing")
      assert_eq(findings[3].rule_id, "role-link-name-missing")
    }
    Audited(_) =>
      fail("empty and decorative-image-only custom roles must report")
    ConfigurationError(_) =>
      fail("known custom role name rules must be accepted")
  }
}

///|
test "custom role name checks run for documents and not native name-rule targets" {
  let document = "<!doctype html><html lang=\"en\"><head><title>Page</title></head><body>" +
    "<button></button><a href=\"/empty\"></a><div role=\"button\"></div>" +
    "<a role=\"link\"></a></body></html>"
  let selected = ["role-button-name-missing", "role-link-name-missing"]
  match @a11ytrace.audit_html_with_rules(document, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "role-button-name-missing")
      assert_eq(findings[1].rule_id, "role-link-name-missing")
    }
    Audited(_) =>
      fail(
        "document custom roles must be checked while native targets are excluded",
      )
    ConfigurationError(_) =>
      fail("known custom role name rules must be accepted")
  }
}

///|
test "custom radio roles accept names and report empty effective roles" {
  let selected = ["role-radio-name-missing"]
  let named = "<span id=\"shared\" aria-label=\"Shared name\"></span>" +
    "<div role=\"radio\">Option</div>" +
    "<div role=\"radio\"><img src=\"option.svg\" alt=\"Option image\"></div>" +
    "<div role=\"radio\" aria-labelledby=\"shared\"></div>" +
    "<div role=\"future-role radio\" aria-label=\"Fallback role\"></div>"
  match @a11ytrace.audit_html_fragment_with_rules(named, selected) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("supported custom-radio name sources must not report")
    ConfigurationError(_) => fail("the custom radio rule must be selectable")
  }
  let missing = "<div role=\"radio\"> </div>" +
    "<div role=\"radio\"><img src=\"decorative.svg\" alt=\"\"></div>" +
    "<div role=\"future-role radio\"></div>"
  match @a11ytrace.audit_html_fragment_with_rules(missing, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].rule_id, "role-radio-name-missing")
      assert_eq(findings[1].rule_id, "role-radio-name-missing")
      assert_eq(findings[2].rule_id, "role-radio-name-missing")
    }
    Audited(_) =>
      fail("empty and decorative-image-only custom radios must report")
    ConfigurationError(_) => fail("the custom radio rule must be selectable")
  }
  let document = "<!doctype html><html lang=\"en\"><head><title>Page</title></head>" +
    "<body><div role=\"radio\"></div></body></html>"
  match @a11ytrace.audit_html_with_rules(document, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "role-radio-name-missing")
    }
    Audited(_) => fail("the custom radio rule must also run for documents")
    ConfigurationError(_) => fail("the custom radio rule must be selectable")
  }
}

///|
test "custom radio checks keep native controls separate and preserve JSON reviews" {
  let fragment = "<input type=\"radio\"><input type=\"radio\" role=\"radio\">" +
    "<div role=\"radio\"><svg></svg></div>"
  let detailed = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(fragment, [
      "form-control-name-missing", "role-radio-name-missing",
    ]) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(result) => result
    _ => fail("known native and custom radio name rules must audit")
  }
  assert_eq(detailed.findings.length(), 2)
  assert_eq(detailed.findings[0].rule_id, "form-control-name-missing")
  assert_eq(detailed.findings[1].rule_id, "form-control-name-missing")
  assert_eq(detailed.review_items.length(), 1)
  assert_eq(detailed.review_items[0].rule_id, "role-radio-name-missing")
  match @json.parse(@a11ytrace.render_detailed_audit_json(detailed)) {
    {
      "findings": Array(
        [{ "rule_id": String(first), .. }, { "rule_id": String(second), .. }]
      ),
      "review_items": Array([{ "rule_id": String(review), .. }]),
      ..
    } => {
      assert_eq(first, "form-control-name-missing")
      assert_eq(second, "form-control-name-missing")
      assert_eq(review, "role-radio-name-missing")
    }
    _ =>
      fail("detailed JSON must retain native findings and custom-radio reviews")
  }
}

///|
test "radio required state and values distinguish custom and native markup" {
  let selected = ["aria-required-property-missing", "aria-state-value-invalid"]
  let markup = "<div role=\"radio\"></div>" +
    "<div role=\"radio\" aria-checked=\"mixed\"></div>" +
    "<div role=\"radio\" aria-checked=\"true\"></div>" +
    "<div role=\"radio\" aria-checked=\"false\"></div>" +
    "<div role=\"future-role radio\" aria-checked=\"true\"></div>" +
    "<input type=\"radio\"><input type=\"radio\" role=\"radio\">"
  match @a11ytrace.audit_html_fragment_with_rules(markup, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "aria-required-property-missing")
      assert_eq(findings[1].rule_id, "aria-state-value-invalid")
    }
    Audited(_) =>
      fail("radio state checks must distinguish missing and invalid values")
    ConfigurationError(_) => fail("known radio state rules must be selectable")
  }
}

///|
test "scrollbar required properties distinguish missing values and invalid IDREFs" {
  let selected = ["aria-required-property-missing", "aria-idref-invalid"]
  let markup = "<div id=\"viewport\"></div>" +
    "<div role=\"scrollbar\" aria-valuenow=\"3\"></div>" +
    "<div role=\"scrollbar\" aria-controls=\"viewport\"></div>" +
    "<div role=\"scrollbar\"></div>" +
    "<div role=\"scrollbar\" aria-controls=\"viewport\" aria-valuenow=\"0\"></div>" +
    "<div role=\"scrollbar\" aria-controls=\"missing\" aria-valuenow=\"5\"></div>"
  match @a11ytrace.audit_html_fragment_with_rules(markup, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 4)
      assert_eq(findings[0].rule_id, "aria-required-property-missing")
      assert_eq(
        findings[0].message,
        "This scrollbar role omits required aria-controls.",
      )
      assert_eq(findings[1].rule_id, "aria-required-property-missing")
      assert_eq(
        findings[1].message,
        "This scrollbar role omits required aria-valuenow.",
      )
      assert_eq(findings[2].rule_id, "aria-required-property-missing")
      assert_eq(
        findings[2].message,
        "This scrollbar role omits required aria-controls and aria-valuenow.",
      )
      assert_eq(findings[3].rule_id, "aria-idref-invalid")
    }
    Audited(_) =>
      fail("scrollbar required properties and IDREFs must be distinct")
    ConfigurationError(_) => fail("selected scrollbar rules must be accepted")
  }
}

///|
test "scrollbar requirements use role fallback and leave spinbutton defaults alone" {
  let selected = ["aria-required-property-missing"]
  let markup = "<div role=\"future-role scrollbar\" aria-controls=\"target\"></div>" +
    "<div role=\"spinbutton\"></div><div role=\"slider\" aria-valuenow=\"1\"></div>" +
    "<div role=\"combobox\"></div>"
  match @a11ytrace.audit_html_fragment_with_rules(markup, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "aria-required-property-missing")
      assert_eq(
        findings[0].message,
        "This scrollbar role omits required aria-valuenow.",
      )
      assert_eq(findings[1].rule_id, "aria-required-property-missing")
      assert_eq(
        findings[1].message,
        "This ARIA role omits a required state or property.",
      )
    }
    Audited(_) => fail("only scrollbar and existing selected roles must report")
    ConfigurationError(_) =>
      fail("the required-property rule must be selectable")
  }
}

///|
test "range values accept exact decimals, scientific notation, and default bounds" {
  let selected = ["aria-range-value-invalid"]
  let markup = "<div role=\"slider\" aria-valuenow=\"0\"></div>" +
    "<div role=\"scrollbar\" aria-valuemin=\"-1.5\" aria-valuemax=\".5\" aria-valuenow=\"-0.5\"></div>" +
    "<div role=\"slider\" aria-valuemin=\"0\" aria-valuemax=\"1e2\" aria-valuenow=\"100.0\"></div>" +
    "<div role=\"future-role slider\" aria-valuemin=\"-.1\" aria-valuemax=\".1\" aria-valuenow=\"0\"></div>"
  match @a11ytrace.audit_html_fragment_with_rules(markup, selected) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("valid exact decimal ranges must not report")
    ConfigurationError(_) => fail("the range-value rule must be selectable")
  }
}

///|
test "range values report malformed values and inconsistent bounds once per element" {
  let selected = ["aria-range-value-invalid"]
  let markup = "<div role=\"slider\" aria-valuenow=\"101\"></div>" +
    "<div role=\"scrollbar\" aria-valuemin=\"10\" aria-valuemax=\"2\" aria-valuenow=\"5\"></div>" +
    "<div role=\"slider\" aria-valuemin=\"not-a-number\" aria-valuenow=\"1\"></div>" +
    "<div role=\"slider\" aria-valuenow=\"NaN\" aria-valuetext=\"ten\"></div>" +
    "<div role=\"slider\" aria-valuemin aria-valuemax=\"bad\" aria-valuenow=\"also-bad\"></div>"
  match @a11ytrace.audit_html_fragment_with_rules(markup, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 5)
      assert_eq(
        findings[0].message,
        "This slider role has aria-valuenow outside its aria-valuemin/aria-valuemax range.",
      )
      assert_eq(
        findings[1].message,
        "This scrollbar role has aria-valuemin greater than aria-valuemax.",
      )
      assert_eq(
        findings[2].message,
        "This slider role has an invalid finite numeric value in aria-valuemin.",
      )
      assert_eq(
        findings[3].message,
        "This slider role has an invalid finite numeric value in aria-valuenow.",
      )
      assert_eq(
        findings[4].message,
        "This slider role has an invalid finite numeric value in aria-valuemin, aria-valuemax, and aria-valuenow.",
      )
    }
    Audited(_) => fail("invalid range values must report deterministically")
    ConfigurationError(_) => fail("the range-value rule must be selectable")
  }
}

///|
test "range values keep required-property ownership and custom-role scope" {
  let selected = ["aria-required-property-missing", "aria-range-value-invalid"]
  let markup = "<div role=\"slider\"></div>" +
    "<div role=\"future-role slider\" aria-valuenow=\"101\"></div>" +
    "<div role=\"spinbutton\" aria-valuemin=\"10\" aria-valuemax=\"2\" aria-valuenow=\"5\"></div>" +
    "<div role=\"progressbar\" aria-valuemin=\"10\" aria-valuemax=\"2\"></div>" +
    "<input type=\"range\" role=\"slider\" aria-valuemin=\"10\" aria-valuemax=\"2\" aria-valuenow=\"5\">" +
    "<input type=\"button\" role=\"slider\" aria-valuemin=\"10\" aria-valuemax=\"2\" aria-valuenow=\"5\">"
  match @a11ytrace.audit_html_fragment_with_rules(markup, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "aria-required-property-missing")
      assert_eq(findings[1].rule_id, "aria-range-value-invalid")
    }
    Audited(_) =>
      fail("missing values and non-custom range roles must stay separate")
    ConfigurationError(_) => fail("known range rules must be selectable")
  }
}

///|
test "range values preserve diagnostics and review unbounded exponents without guessing" {
  let detailed = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(
      "<div role=\"slider\" aria-valuenow=\"101\"></span>" +
      "<div role=\"scrollbar\" aria-valuenow=\"1e1000000\"></div>",
      ["aria-range-value-invalid"],
    ) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(result) => result
    _ => fail("the range-value rule must audit malformed fragments")
  }
  assert_true(
    detailed.status is @a11ytrace.DetailedAuditStatus::FindingsWithParseErrors,
  )
  assert_eq(detailed.findings.length(), 1)
  assert_eq(detailed.findings[0].rule_id, "aria-range-value-invalid")
  assert_eq(detailed.review_items.length(), 1)
  assert_eq(detailed.review_items[0].rule_id, "aria-range-value-invalid")
  assert_true(detailed.review_items[0].reason.contains("exponent too large"))
  match @json.parse(@a11ytrace.render_detailed_audit_json(detailed)) {
    { "assessment": String("findings"), "review_items": Array([_]), .. } => ()
    _ => fail("range review items must remain visible in detailed JSON")
  }
}

///|
test "custom textbox and searchbox roles require author-provided names" {
  let selected = ["role-textbox-name-missing", "role-searchbox-name-missing"]
  let named = "<span id=\"search-label\">Search catalog</span>" +
    "<svg id=\"svg-author-name\" aria-label=\"Search icon\"></svg>" +
    "<div role=\"textbox\" aria-labelledby=\"search-label\"></div>" +
    "<div role=\"searchbox\" aria-label=\"Search site\"></div>" +
    "<div role=\"textbox\" title=\"Notes\"></div>" +
    "<div role=\"searchbox\" aria-labelledby=\"svg-author-name\"></div>" +
    "<div role=\"future-role searchbox\" aria-label=\"Fallback search\"></div>"
  match @a11ytrace.audit_html_fragment_with_rules(named, selected) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("supported custom text-input names must not report")
    ConfigurationError(_) => fail("custom text-input rules must be selectable")
  }
  let unnamed = "<div role=\"textbox\"></div>" +
    "<div role=\"searchbox\" contenteditable>Typed search</div>" +
    "<div role=\"textbox\" placeholder=\"Email\">Visible content</div>" +
    "<div role=\"searchbox\" aria-placeholder=\"Search\"></div>" +
    "<div role=\"future-role textbox\">Content is not a name</div>"
  match @a11ytrace.audit_html_fragment_with_rules(unnamed, selected) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 5)
      assert_eq(findings[0].rule_id, "role-textbox-name-missing")
      assert_eq(findings[1].rule_id, "role-searchbox-name-missing")
      assert_eq(findings[2].rule_id, "role-textbox-name-missing")
      assert_eq(findings[3].rule_id, "role-searchbox-name-missing")
      assert_eq(findings[4].rule_id, "role-textbox-name-missing")
    }
    Audited(_) =>
      fail(
        "contenteditable, descendants, and placeholders must not name text roles",
      )
    ConfigurationError(_) => fail("custom text-input rules must be selectable")
  }
}

///|
test "custom text input roles keep native findings separate and review SVG IDREFs" {
  let fragment = "<input><textarea></textarea>" +
    "<svg id=\"search-icon\"><title>Search</title></svg>" +
    "<div role=\"searchbox\" aria-labelledby=\"search-icon\"></div>"
  let detailed = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(fragment, [
      "form-control-name-missing", "role-textbox-name-missing", "role-searchbox-name-missing",
    ]) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(result) => result
    _ => fail("known native and custom text-input name rules must audit")
  }
  assert_eq(detailed.findings.length(), 2)
  assert_eq(detailed.findings[0].rule_id, "form-control-name-missing")
  assert_eq(detailed.findings[1].rule_id, "form-control-name-missing")
  assert_eq(detailed.review_items.length(), 1)
  assert_eq(detailed.review_items[0].rule_id, "role-searchbox-name-missing")
  match @json.parse(@a11ytrace.render_detailed_audit_json(detailed)) {
    {
      "findings": Array(
        [{ "rule_id": String(first), .. }, { "rule_id": String(second), .. }]
      ),
      "review_items": Array([{ "rule_id": String(review), .. }]),
      ..
    } => {
      assert_eq(first, "form-control-name-missing")
      assert_eq(second, "form-control-name-missing")
      assert_eq(review, "role-searchbox-name-missing")
    }
    _ => fail("detailed JSON must retain custom text-input name reviews")
  }
}

///|
test "custom role SVG naming is a review and JSON keeps native findings distinct" {
  let fragment = "<button></button><a href=\"/empty\"></a>" +
    "<div role=\"button\"></div><span role=\"link\"><svg></svg></span>"
  let detailed = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(fragment, [
      "button-name-missing", "link-name-missing", "role-button-name-missing", "role-link-name-missing",
    ]) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(result) => result
    _ => fail("known custom role name rules must audit")
  }
  assert_eq(detailed.findings.length(), 3)
  assert_eq(detailed.findings[0].rule_id, "button-name-missing")
  assert_eq(detailed.findings[1].rule_id, "link-name-missing")
  assert_eq(detailed.findings[2].rule_id, "role-button-name-missing")
  assert_eq(detailed.review_items.length(), 1)
  assert_eq(detailed.review_items[0].rule_id, "role-link-name-missing")
  let json = @a11ytrace.render_detailed_audit_json(detailed)
  match @json.parse(json) {
    {
      "findings": Array(
        [
          { "rule_id": String(first), .. },
          { "rule_id": String(second), .. },
          { "rule_id": String(third), .. },
        ]
      ),
      "review_items": Array([{ "rule_id": String(review), .. }]),
      ..
    } => {
      assert_eq(first, "button-name-missing")
      assert_eq(second, "link-name-missing")
      assert_eq(third, "role-button-name-missing")
      assert_eq(review, "role-link-name-missing")
    }
    _ => fail("detailed JSON must preserve custom role finding and review IDs")
  }
}

///|
test "next-release ARIA compatibility and grouping rules stay narrowly scoped" {
  let fragment = "<div role=\"button\" aria-checked=\"true\"></div>" +
    "<div role=\"future-role radio\" aria-checked=\"true\"></div>" +
    "<input type=\"checkbox\" aria-checked=\"true\">" +
    "<li>Orphan</li><menu><li>Allowed</li></menu>" +
    "<fieldset><input><select></select></fieldset>" +
    "<fieldset><legend>Contact</legend><input><select></select></fieldset>" +
    "<fieldset><input></fieldset><template><fieldset><input><select></select></fieldset></template>"
  match
    @a11ytrace.audit_html_fragment_with_rules(fragment, [
      "aria-checked-role-incompatible", "listitem-orphan", "fieldset-legend-missing",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 3)
      assert_eq(findings[0].rule_id, "aria-checked-role-incompatible")
      assert_eq(findings[1].rule_id, "listitem-orphan")
      assert_eq(findings[2].rule_id, "fieldset-legend-missing")
    }
    Audited(_) =>
      fail("the selected next-release rules should find the three scoped cases")
    ConfigurationError(_) => fail("next-release rule IDs must be selectable")
  }
}

///|
test "next-release grouping rules retain document order and parser diagnostics" {
  let fragment = "<fieldset><legend></legend><input><textarea></textarea></fieldset>" +
    "<div role=\"slider\" aria-checked=\"false\"></div></span>"
  let detailed = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(fragment, [
      "fieldset-legend-missing", "aria-checked-role-incompatible",
    ]) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(result) => result
    _ => fail("known next-release rules should produce a detailed audit")
  }
  assert_eq(detailed.findings.length(), 2)
  assert_eq(detailed.findings[0].rule_id, "fieldset-legend-missing")
  assert_eq(detailed.findings[1].rule_id, "aria-checked-role-incompatible")
  assert_true(detailed.parse_diagnostics.length() > 0)
  match @json.parse(@a11ytrace.render_detailed_audit_json(detailed)) {
    {
      "findings": Array(
        [{ "rule_id": String(first), .. }, { "rule_id": String(second), .. }]
      ),
      ..
    } => {
      assert_eq(first, "fieldset-legend-missing")
      assert_eq(second, "aria-checked-role-incompatible")
    }
    _ => fail("detailed JSON must keep next-release rule IDs")
  }
}

///|
test "aria checked compatibility accepts every supported explicit role and fallback" {
  let supported = "<div role=\"checkbox\" aria-checked=\"true\"></div>" +
    "<div role=\"radio\" aria-checked=\"false\"></div>" +
    "<div role=\"switch\" aria-checked=\"true\"></div>" +
    "<div role=\"menuitemcheckbox\" aria-checked=\"mixed\"></div>" +
    "<div role=\"menuitemradio\" aria-checked=\"false\"></div>" +
    "<div role=\"option\" aria-checked=\"true\"></div>" +
    "<div role=\"treeitem\" aria-checked=\"mixed\"></div>" +
    "<div role=\"future-role radio\" aria-checked=\"true\"></div>" +
    "<input type=\"checkbox\" aria-checked=\"true\">"
  match
    @a11ytrace.audit_html_fragment_with_rules(supported, [
      "aria-checked-role-incompatible",
    ]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) =>
      fail("supported and native checked states must not be incompatible")
    ConfigurationError(_) => fail("the compatibility rule must be selectable")
  }
  let unsupported = "<div role=\"button\" aria-checked=\"true\"></div>" +
    "<div role=\"future-role slider\" aria-checked=\"false\"></div>" +
    "<div role=\"unknown-role\" aria-checked=\"true\"></div>"
  match
    @a11ytrace.audit_html_fragment_with_rules(unsupported, [
      "aria-checked-role-incompatible",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].element_path, "div:nth-of-type(1)")
      assert_eq(findings[1].element_path, "div:nth-of-type(2)")
    }
    Audited(_) => fail("only known unsupported explicit roles must report")
    ConfigurationError(_) => fail("the compatibility rule must be selectable")
  }
}

///|
test "checked role compatibility avoids duplicate invalid-state findings by default" {
  let html = "<div role=\"button\" aria-checked=\"not-a-state\"></div>" +
    "<div role=\"radio\" aria-checked=\"mixed\"></div>"
  match
    @a11ytrace.audit_html_fragment_with_rules(html, [
      "aria-checked-role-incompatible", "aria-state-value-invalid",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "aria-checked-role-incompatible")
      assert_eq(findings[1].rule_id, "aria-state-value-invalid")
    }
    Audited(_) =>
      fail("incompatible and invalid values must have distinct owners")
    ConfigurationError(_) => fail("both checked rules must be selectable")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(html, ["aria-state-value-invalid"]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 2)
    Audited(_) =>
      fail("selecting the established state-value rule preserves its behavior")
    ConfigurationError(_) =>
      fail("the established state rule must remain selectable")
  }
}

///|
test "listitem parentage uses recovered DOM without duplicating list child findings" {
  let fragment = "<li>Orphan</li><ul><li>Good</li></ul><ol><li>Good</li></ol>" +
    "<menu><li>Good</li></menu><template><li>Ignored</li></template>"
  match
    @a11ytrace.audit_html_fragment_with_rules(fragment, ["listitem-orphan"]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 1)
    Audited(_) => fail("only the recovered orphan list item should report")
    ConfigurationError(_) =>
      fail("the orphan list item rule must be selectable")
  }
  let document = "<!doctype html><html><head><title>List</title></head><body><li>Orphan</li></body></html>"
  match @a11ytrace.audit_html_with_rules(document, ["listitem-orphan"]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 1)
    Audited(_) => fail("the list-item rule must also run on complete documents")
    ConfigurationError(_) =>
      fail("the orphan list item rule must be selectable")
  }
  let recovered = "<ul><div><li>Nested orphan</li></div></ul></span>"
  match
    @a11ytrace.audit_html_fragment_with_rules(recovered, [
      "list-structure-invalid", "listitem-orphan",
    ]) {
    Audited(FindingsWithParseErrors(findings, diagnostics)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].rule_id, "list-structure-invalid")
      assert_eq(findings[1].rule_id, "listitem-orphan")
      assert_true(diagnostics.length() > 0)
    }
    Audited(_) =>
      fail("recovered DOM findings and diagnostics must remain available")
    ConfigurationError(_) => fail("both list rules must be selectable")
  }
}

///|
test "fieldset legend prompt requires a direct named first legend" {
  let html = "<fieldset><div><legend>Nested</legend></div><input><select></select></fieldset>" +
    "<fieldset><legend> </legend><legend>Later</legend><input><select></select></fieldset>" +
    "<fieldset><legend>First</legend><legend>Later</legend><input><select></select></fieldset>" +
    "<fieldset><input></fieldset>"
  match
    @a11ytrace.audit_html_fragment_with_rules(html, ["fieldset-legend-missing"]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 2)
      assert_eq(findings[0].element_path, "fieldset:nth-of-type(1)")
      assert_eq(findings[1].element_path, "fieldset:nth-of-type(2)")
    }
    Audited(_) =>
      fail("only missing or empty direct first legends should prompt")
    ConfigurationError(_) => fail("the fieldset legend rule must be selectable")
  }
}

///|
test "role attribute compatibility uses its small inherited and global-property table" {
  let compatible = "<div role=\"option\" aria-checked=\"true\"></div>" +
    "<div role=\"searchbox\" aria-autocomplete=\"list\"></div>" +
    "<div role=\"searchbox\" aria-placeholder=\"Search\"></div>" +
    "<div role=\"treegrid\" aria-multiselectable=\"true\"></div>" +
    "<div role=\"button\" aria-describedby=\"help\"></div>" +
    "<div role=\"button\" aria-label=\"Save\"></div>" +
    "<span id=\"help\">Help</span>"
  match
    @a11ytrace.audit_html_fragment_with_rules(compatible, [
      "aria-checked-role-incompatible", "aria-role-attribute-incompatible",
    ]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) =>
      fail("documented supported and global attributes must not report")
    ConfigurationError(_) => fail("the role attribute rule must be selectable")
  }
  let incompatible = "<div role=\"button\" aria-autocomplete=\"list\"></div>" +
    "<div role=\"emphasis\" aria-label=\"Stress\" aria-labelledby=\"label\"></div>" +
    "<div role=\"future-role button\" aria-placeholder=\"Find\"></div>" +
    "<div role=\"unknown-role\" aria-placeholder=\"Ignored\"></div>" +
    "<div role=\"slider\" aria-selected=\"true\"></div>" +
    "<input aria-autocomplete=\"list\"><button role=\"button\" aria-autocomplete=\"list\">Native</button>"
  match
    @a11ytrace.audit_html_fragment_with_rules(incompatible, [
      "aria-role-attribute-incompatible",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 4)
      assert_eq(findings[0].element_path, "div:nth-of-type(1)")
      assert_true(findings[0].message.contains("aria-autocomplete"))
      assert_eq(findings[1].element_path, "div:nth-of-type(2)")
      assert_true(findings[1].message.contains("aria-label"))
      assert_eq(findings[2].element_path, "div:nth-of-type(2)")
      assert_true(findings[2].message.contains("aria-labelledby"))
      assert_eq(findings[3].element_path, "div:nth-of-type(3)")
      assert_true(findings[3].message.contains("aria-placeholder"))
    }
    Audited(_) =>
      fail("only modeled effective roles and attributes should report")
    ConfigurationError(_) => fail("the role attribute rule must be selectable")
  }
}

///|
test "role attribute compatibility keeps specialized checked and JSON findings distinct" {
  let fragment = "<div role=\"button\" aria-checked=\"true\" aria-autocomplete=\"list\"></div>" +
    "<div role=\"option\" aria-checked=\"true\"></div>"
  let detailed = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(fragment, [
      "aria-checked-role-incompatible", "aria-role-attribute-incompatible",
    ]) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(result) => result
    _ => fail("known compatibility rules must audit a fragment")
  }
  assert_eq(detailed.findings.length(), 2)
  assert_eq(detailed.findings[0].rule_id, "aria-checked-role-incompatible")
  assert_eq(detailed.findings[1].rule_id, "aria-role-attribute-incompatible")
  match @json.parse(@a11ytrace.render_detailed_audit_json(detailed)) {
    {
      "findings": Array(
        [{ "rule_id": String(first), .. }, { "rule_id": String(second), .. }]
      ),
      ..
    } => {
      assert_eq(first, "aria-checked-role-incompatible")
      assert_eq(second, "aria-role-attribute-incompatible")
    }
    _ => fail("JSON must retain one finding per distinct compatibility reason")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(fragment, [
      "aria-checked-role-incompatible",
    ]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 1)
    Audited(_) =>
      fail("selecting the established checked rule keeps its behavior")
    ConfigurationError(_) =>
      fail("the established checked rule must remain selectable")
  }
}

///|
test "language-tag checks accept ACT known-primary examples without strict later-subtag parsing" {
  let page = "<!doctype html><html lang=\"EN\"><head><title>Languages</title></head><body>" +
    "<p lang=\"zh-Hans\">中文</p><p lang=\"fr-CH\">Bonjour</p>" +
    "<p lang=\"en-US-GB\">English</p><p lang=\"de-hello\">Deutsch</p></body></html>"
  match
    @a11ytrace.audit_html_with_rules(page, [
      "html-lang-invalid", "element-lang-invalid",
    ]) {
    Audited(Findings(findings)) => assert_eq(findings.length(), 0)
    Audited(_) => fail("known primary language subtags must be accepted")
    ConfigurationError(_) => fail("language-tag rules must be selectable")
  }
}

///|
test "language-tag checks report unknown primaries and obvious separators without owning empty values" {
  let page = "<!doctype html><html lang=\"em-US\"><head><title>Languages</title></head><body>" +
    "<p lang=\"eng\">Legacy code</p><p lang=\"en--US\">Malformed</p>" +
    "<p lang=\"en_US\">Malformed</p><p lang=\" \">Empty remains outside this rule</p></body></html>"
  match
    @a11ytrace.audit_html_with_rules(page, [
      "html-lang-invalid", "element-lang-invalid",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 4)
      assert_eq(findings[0].rule_id, "html-lang-invalid")
      assert_eq(findings[1].rule_id, "element-lang-invalid")
      assert_eq(findings[2].rule_id, "element-lang-invalid")
      assert_eq(findings[3].rule_id, "element-lang-invalid")
    }
    Audited(_) =>
      fail("unknown primary subtags and malformed separators must report")
    ConfigurationError(_) => fail("language-tag rules must be selectable")
  }
  let empty_page = "<!doctype html><html lang=\" \"><head><title>Languages</title></head><body></body></html>"
  match
    @a11ytrace.audit_html_with_rules(empty_page, [
      "html-lang-missing", "html-lang-invalid",
    ]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "html-lang-missing")
    }
    Audited(_) =>
      fail("empty html lang must keep the existing missing-rule owner")
    ConfigurationError(_) =>
      fail("existing and new language rules must be selectable")
  }
}

///|
test "element language tags respect document-body and fragment scope" {
  let document = "<!doctype html><html lang=\"en\"><head><title lang=\"unknown\">Title</title></head>" +
    "<body><p lang=\"unknown\">Body text</p><template><p lang=\"unknown\">Ignored</p></template></body></html>"
  match @a11ytrace.audit_html_with_rules(document, ["element-lang-invalid"]) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(
        findings[0].element_path,
        "html:nth-of-type(1) > body:nth-of-type(1) > p:nth-of-type(1)",
      )
    }
    Audited(_) =>
      fail(
        "only recovered body-subtree language markup should report in documents",
      )
    ConfigurationError(_) => fail("element language rule must be selectable")
  }
  match
    @a11ytrace.audit_html_fragment_with_rules(
      "<p lang=\"unknown\">Component</p>",
      ["html-lang-invalid", "element-lang-invalid"],
    ) {
    Audited(Findings(findings)) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "element-lang-invalid")
      assert_eq(findings[0].element_path, "p:nth-of-type(1)")
    }
    Audited(_) =>
      fail("fragments must audit local element markup but not page html lang")
    ConfigurationError(_) => fail("language-tag rules must be selectable")
  }
}

///|
test "language-tag findings preserve diagnostics document order and JSON" {
  let fragment = "<img src=\"missing.png\"><p lang=\"unknown\">Text</p></span>"
  let detailed = match
    @a11ytrace.audit_html_fragment_detailed_with_rules(fragment, [
      "img-alt-missing", "element-lang-invalid",
    ]) {
    @a11ytrace.DetailedConfiguredAuditResult::Audited(result) => result
    _ =>
      fail("selected language and image rules must audit recovered fragments")
  }
  assert_eq(detailed.findings.length(), 2)
  assert_eq(detailed.findings[0].rule_id, "img-alt-missing")
  assert_eq(detailed.findings[1].rule_id, "element-lang-invalid")
  assert_true(detailed.parse_diagnostics.length() > 0)
  match @json.parse(@a11ytrace.render_detailed_audit_json(detailed)) {
    {
      "findings": Array(
        [{ "rule_id": String(first), .. }, { "rule_id": String(second), .. }]
      ),
      "parse_diagnostics": Array([_, ..]),
      ..
    } => {
      assert_eq(first, "img-alt-missing")
      assert_eq(second, "element-lang-invalid")
    }
    _ =>
      fail("detailed JSON must retain language findings and parser diagnostics")
  }
}
