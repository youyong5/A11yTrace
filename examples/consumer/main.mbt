///|
#coverage.skip
fn main {
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
