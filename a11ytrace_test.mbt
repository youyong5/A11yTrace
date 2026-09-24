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
  let result = @a11ytrace.audit_html_fragment_detailed(
    "<div aria-hidden=\"true\"><button aria-label=\"Close\"></button></div>",
  )
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
  let result = @a11ytrace.audit_html_fragment_detailed(html)
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
  let result = @a11ytrace.audit_html_fragment_detailed(
    "<div aria-hidden=\"true\"><summary>More</summary><video controls></video></div>",
  )
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
test "svg navigation names are review items and abstract roles are definite findings" {
  let document = "<!doctype html><html lang=\"en\"><head><title>Page</title></head><body>" +
    "<nav><svg><title>Menu</title></svg></nav><nav aria-label=\"Primary\"></nav>" +
    "<div role=\"button landmark\"></div><div role=\"\"></div></body></html>"
  let detailed = @a11ytrace.audit_html_detailed(document)
  assert_eq(detailed.review_items.length(), 1)
  assert_eq(
    detailed.review_items[0].rule_id,
    "navigation-landmark-name-missing",
  )
  let abstract_findings = detailed.findings.filter(fn(finding) {
    finding.rule_id == "aria-abstract-role"
  })
  assert_eq(abstract_findings.length(), 1)
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
  assert_eq(rules.length(), 22)
  assert_eq(rules[0].id, "img-alt-missing")
  assert_eq(rules[19].id, "meta-refresh-delay")
  assert_eq(rules[20].id, "aria-state-value-invalid")
  assert_eq(rules[21].id, "button-implicit-submit")
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
  assert_true(@a11ytrace.rule_metadata("not-a-rule") is None)
  let content_ids = @a11ytrace.content_rule_ids()
  assert_true(content_ids.contains("img-alt-missing"))
  assert_true(!content_ids.contains("document-title-missing"))
  let document_ids = @a11ytrace.document_rule_ids()
  assert_true(document_ids.contains("document-title-missing"))
  assert_true(document_ids.contains("meta-refresh-delay"))
  assert_eq(@a11ytrace.review_rule_ids(), ["aria-hidden-focus-review"])
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
  assert_eq(rule_ids.length(), 22)
  assert_eq(rule_ids[0], "img-alt-missing")
  assert_eq(rule_ids[4], "heading-level-skipped")
  assert_eq(rule_ids[5], "heading-name-missing")
  assert_eq(rule_ids[6], "document-title-missing")
  assert_eq(rule_ids[9], "duplicate-id")
  assert_eq(rule_ids[10], "reference-target-invalid")
  assert_eq(rule_ids[12], "area-alt-missing")
  assert_eq(rule_ids[13], "aria-hidden-focus-review")
  assert_eq(rule_ids[18], "aria-abstract-role")
  assert_eq(rule_ids[19], "meta-refresh-delay")
  assert_eq(rule_ids[20], "aria-state-value-invalid")
  assert_eq(rule_ids[21], "button-implicit-submit")
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
