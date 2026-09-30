# A11yTrace

A reusable MoonBit library for focused, static HTML accessibility checks. It is a library first: callers pass HTML or component fragments and receive structured findings rather than relying on a CLI exit code.

## Install and use

The published package is `youyong5/a11ytrace@0.5.0`. In a fresh MoonBit
project, install it from Mooncakes and import the public package name:

```text
moon new a11ytrace-demo
cd a11ytrace-demo
moon add youyong5/a11ytrace@0.5.0
```

Add this import to the generated `cmd/main/moon.pkg` before its `pkgtype`
declaration:

```moonbit
import {
  "youyong5/a11ytrace" @a11ytrace,
}
```

Then replace `cmd/main/main.mbt` with this minimal audit and run it:

```moonbit

fn main {
  match @a11ytrace.audit_html_fragment("<img src=\"logo.svg\">") {
    Findings(findings) => println(findings[0].rule_id)
    FindingsWithParseErrors(findings, _) => println(findings[0].rule_id)
    ParseErrors(diagnostics) => println(diagnostics[0].message)
  }
}
```

```text
moon run cmd/main
```

To work from a checkout instead, clone it and run `moon check`; the module name
is still `youyong5/a11ytrace`.

## Release 0.5.0

Release 0.5.0 has 80 selectable built-in IDs: 49 confirmed Finding
checks, 7 static hints, and 24 ReviewItem triggers. These are distinct result
classes, not 80 automatic WCAG checks. Its public WCAG directory records the 55 current
WCAG 2.2 A/AA success criteria and one historical WCAG 2.1 entry (4.1.1,
removed in 2.2): 10 criteria have narrow partial automatic checks, 32 have
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

The 80 built-in rules cover image/text alternatives; native and selected ARIA widget names including custom button/link/radio/textbox/searchbox roles; document and landmark structure; non-empty page and content language tags with known IANA primary subtags; ID/label/table relationships including an explicit label-to-nonlabelable-built-in target, multiple labelable descendants, and orphan list items; WAI-ARIA 1.2 attribute names, concrete-role fallback, selected values and required properties (including scrollbar `aria-controls` and `aria-valuenow`), exact static slider/scrollbar range-value consistency, a narrow explicit-role `aria-checked` compatibility check, a selected required-context-role relationship table, and a documented selected role/property compatibility table; plus clear static media, keyboard, focus, target-size, dragging, form and authentication review triggers. `fieldset-legend-missing` is a static grouping prompt, not a WCAG verdict. `aria-attribute-undefined`, `role-value-invalid`, `table-scope-invalid`, `aria-range-value-invalid`, `aria-required-context-role`, the language-tag rules, the label-association rules, `aria-checked-role-incompatible`, and `aria-role-attribute-incompatible` are narrow static checks; they do not make this library a complete ARIA or table-association validator. Shared `aria-labelledby` parsing preserves IDREF order and accepts a direct target's supported static ARIA-label/text-image-alt/title source, but does not recursively implement the browser's full accessible-name traversal. Potential focusable content in `aria-hidden` subtrees is a manual-review result, not an asserted rendered violation. The checks are deliberately scoped, not a complete Accessible Name implementation, ARIA validator, or WCAG conformance decision. Fragment references are resolved only inside the supplied markup. The optional CLI currently has error paths that exit with status 0, so CI integrations should consume the library's structured results instead.

See [README.mbt.md](README.mbt.md) for full MoonBit examples, JSON fields, rules, and the native CLI; [RULES.md](RULES.md) for rule boundaries; [LANGUAGE-SUBTAGS.md](LANGUAGE-SUBTAGS.md) for generated IANA data and its limits; [ARIA-ROLE-ATTRIBUTE-TABLE.md](ARIA-ROLE-ATTRIBUTE-TABLE.md) and [ARIA-REQUIRED-CONTEXT-TABLE.md](ARIA-REQUIRED-CONTEXT-TABLE.md) for the limited, auditable ARIA tables; [RULE-INVENTORY.md](RULE-INVENTORY.md) for the 80-ID execution/test inventory; [WCAG-COVERAGE.md](WCAG-COVERAGE.md) for the A/AA coverage directory and review steps; and [REFERENCE-COMPARISON.md](REFERENCE-COMPARISON.md) for the scoped HTML-Validate/axe-core/ACT comparison and static-analysis limits.
