# A11yTrace

A reusable MoonBit library for focused, static HTML accessibility checks. It is a library first: callers pass HTML or component fragments and receive structured findings rather than relying on a CLI exit code.

## Install and use

This repository has not been published to Mooncakes yet. To work from a checkout, clone it and run `moon check`; the module name is `youyong5/a11ytrace`.

```moonbit
import {
  "youyong5/a11ytrace" @a11ytrace,
}

match @a11ytrace.audit_html_fragment("<button></button>") {
  Findings(findings) => println(findings[0].rule_id)
  FindingsWithParseErrors(findings, diagnostics) => ()
  ParseErrors(diagnostics) => ()
}
```

Public entry points include `audit_html`, `audit_html_fragment`, their rule-selection variants, `available_rule_ids`, and `render_audit_json`. Inputs containing `<!doctype` or `<html` use full-document parsing, so page-only checks can verify a non-empty document title and `html[lang]`; component fragments never receive those page-only findings.

Run the in-module consumer example from the repository root:

```text
moon run --target native examples/consumer
```

The current rules cover image alt presence; static names for form controls, links, buttons, headings, and iframes; heading skips; complete-document title/language presence; and duplicate IDs in one audited input scope. The checks are deliberately scoped heuristics, not a complete Accessible Name implementation or a WCAG conformance decision. Fragment references are resolved only inside the supplied markup. The optional CLI currently has error paths that exit with status 0, so CI integrations should consume the library's structured results instead.

See [README.mbt.md](README.mbt.md) for full MoonBit examples, JSON fields, rules, and the native CLI; [RULES.md](RULES.md) for rule boundaries; and [REFERENCE-COMPARISON.md](REFERENCE-COMPARISON.md) for the scoped HTML-Validate/axe-core/ACT comparison and static-analysis limits.
