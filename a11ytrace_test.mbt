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
  assert_eq(rule_ids.length(), 13)
  assert_eq(rule_ids[0], "img-alt-missing")
  assert_eq(rule_ids[4], "heading-level-skipped")
  assert_eq(rule_ids[5], "heading-name-missing")
  assert_eq(rule_ids[6], "document-title-missing")
  assert_eq(rule_ids[9], "duplicate-id")
  assert_eq(rule_ids[10], "reference-target-invalid")
  assert_eq(rule_ids[12], "area-alt-missing")
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
