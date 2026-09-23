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

Public entry points include `audit_html`, `audit_html_fragment`, their rule-selection variants, `available_rule_ids`, and `render_audit_json`.

Run the in-module consumer example from the repository root:

```text
moon run --target native examples/consumer
```

The checks are deliberately scoped heuristics, not a complete Accessible Name implementation or a WCAG conformance decision. Fragment references are resolved only inside the supplied markup. The optional CLI currently has error paths that exit with status 0, so CI integrations should consume the library's structured results instead.

See [README.mbt.md](README.mbt.md) for full MoonBit examples, JSON fields, rules, and the native CLI; see [RULES.md](RULES.md) for rule boundaries.
