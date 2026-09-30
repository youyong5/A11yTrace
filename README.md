# A11yTrace

A reusable MoonBit library for focused, static HTML accessibility checks. It is a library first: callers pass HTML or component fragments and receive structured findings rather than relying on a CLI exit code.

## Install and use

The published package is `youyong5/a11ytrace@0.3.0`. To work from a checkout, clone it and run `moon check`; the module name is `youyong5/a11ytrace`.

## Current development checkout

This checkout has 70 selectable built-in IDs: 40 confirmed Finding checks, 6
static hints, and 24 ReviewItem triggers. These are distinct result classes,
not 70 automatic WCAG checks. Its public WCAG directory records the 55 current
WCAG 2.2 A/AA success criteria and one historical WCAG 2.1 entry (4.1.1,
removed in 2.2): 9 criteria have narrow partial automatic checks, 33 have
specific manual-review procedures, and 13 are not assessed from static HTML.
An empty findings array never demonstrates WCAG conformance.

The detailed JSON renderer also reports `assessment`: `findings`,
`needs_review`, `no_static_findings`, or `parse_errors`. In particular,
review-only output is `needs_review`, not a pass.

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

Public entry points include `audit_html`, `audit_html_fragment`, their rule-selection variants, `available_rule_ids`, and `render_audit_json`. `available_rules`, `rule_metadata`, and named content/document/review selections expose the same built-in rule directory used by the audit APIs. `audit_html_detailed`, `audit_html_fragment_detailed`, their detailed selection variants, and `render_detailed_audit_json` additionally keep definite findings separate from parser diagnostics and browser/CSS review items. `wcag_aa_criteria`, `wcag_criterion`, and `audit_html_with_wcag_coverage` expose a version-aware WCAG 2.1/2.2 A/AA coverage directory; they never declare a page conformant. Inputs containing `<!doctype` or `<html` use full-document parsing, so page-only checks can verify a non-empty document title and `html[lang]`; component fragments never receive those page-only findings.

Run the in-module consumer example from the repository root:

```text
moon run --target native examples/consumer
```

The 70 built-in rules cover image/text alternatives; native and selected ARIA widget names including custom button/link/radio/textbox/searchbox roles; document and landmark structure; ID/label/table relationships; WAI-ARIA 1.2 attribute names, concrete-role fallback, selected values and required properties; and clear static media, keyboard, focus, target-size, dragging, form and authentication review triggers. `aria-attribute-undefined`, `role-value-invalid`, and `table-scope-invalid` are narrow static checks; they do not make this library a complete ARIA or table-association validator. Shared `aria-labelledby` parsing preserves IDREF order and accepts a direct target's supported static ARIA-label/text-image-alt/title source, but does not recursively implement the browser's full accessible-name traversal. Potential focusable content in `aria-hidden` subtrees is a manual-review result, not an asserted rendered violation. The checks are deliberately scoped, not a complete Accessible Name implementation, ARIA validator, or WCAG conformance decision. Fragment references are resolved only inside the supplied markup. The optional CLI currently has error paths that exit with status 0, so CI integrations should consume the library's structured results instead.

See [README.mbt.md](README.mbt.md) for full MoonBit examples, JSON fields, rules, and the native CLI; [RULES.md](RULES.md) for rule boundaries; [RULE-INVENTORY.md](RULE-INVENTORY.md) for the 70-ID execution/test inventory; [WCAG-COVERAGE.md](WCAG-COVERAGE.md) for the A/AA coverage directory and review steps; and [REFERENCE-COMPARISON.md](REFERENCE-COMPARISON.md) for the scoped HTML-Validate/axe-core/ACT comparison and static-analysis limits.
