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
  match @a11ytrace.audit_html(html) {
    Findings(findings) => {
      assert_eq(findings.length(), 5)
      for finding in findings {
        assert_eq(finding.rule_id, "form-control-name-missing")
      }
      assert_eq(findings[0].element_path, "input:nth-of-type(1)")
      assert_eq(findings[4].element_path, "input:nth-of-type(5)")
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
}

///|
test "does not let unrelated explicit labels name another control" {
  match
    @a11ytrace.audit_html(
      "<label for=\"other\">Name <input id=\"name\"></label>",
    ) {
    Findings(findings) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "form-control-name-missing")
      assert_eq(
        findings[0].element_path,
        "label:nth-of-type(1) > input:nth-of-type(1)",
      )
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
  }
  match
    @a11ytrace.audit_html(
      "<label for=\"name\">Name</label><input id=\"other\">",
    ) {
    Findings(findings) => {
      assert_eq(findings.length(), 1)
      assert_eq(findings[0].rule_id, "form-control-name-missing")
      assert_eq(findings[0].element_path, "input:nth-of-type(1)")
    }
    FindingsWithParseErrors(_, _) =>
      fail("valid HTML should have no parser diagnostics")
    ParseErrors(_) => fail("valid HTML should be audited")
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
  assert_eq(rule_ids.length(), 6)
  assert_eq(rule_ids[0], "img-alt-missing")
  assert_eq(rule_ids[4], "heading-level-skipped")
  assert_eq(rule_ids[5], "heading-name-missing")
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
