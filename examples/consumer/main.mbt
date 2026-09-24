///|
#coverage.skip
fn main {
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
