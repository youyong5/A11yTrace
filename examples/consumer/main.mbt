///|
#coverage.skip
fn main {
  let catalog = @a11ytrace.available_rules()
  println("built-in rules: \{catalog.length()}")
  match @a11ytrace.rule_metadata("aria-hidden-focus-review") {
    Some(rule) => println("review rule: \{rule.id} — \{rule.summary}")
    None => panic()
  }
  println("manual-review selection: \{@a11ytrace.review_rule_ids().length()}")
  let detailed = @a11ytrace.audit_html_fragment_detailed(
    "<div aria-hidden=\"true\"><button aria-label=\"Close\"></button></div>",
  )
  let review_count = detailed.review_items.length()
  println("review items: \{review_count}")
  println(@a11ytrace.render_detailed_audit_json(detailed))
  println(@a11ytrace.render_audit_json(component_audit()))
}

///|
fn component_audit() -> @a11ytrace.AuditResult {
  match
    @a11ytrace.audit_html_fragment_with_rules(
      "<button></button><img src=\"badge.png\">",
      ["button-name-missing"],
    ) {
    Audited(result) => result
    ConfigurationError(UnknownRuleId(_)) => panic()
  }
}
