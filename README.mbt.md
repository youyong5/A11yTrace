# A11yTrace

A11yTrace is a small, pure MoonBit library for statically checking HTML accessibility rules.

## Dependency and use

It uses [`bobzhang/html_parser` 0.1.8](https://github.com/bobzhang/html_parser) to parse HTML into a DOM; A11yTrace does not parse HTML with regular expressions.

```moonbit nocheck
import {
  "youyong5/a11ytrace" @a11ytrace,
}

match @a11ytrace.audit_html("<img src=\"logo.svg\">") {
  Findings(findings) => println(findings[0].element_path)
  FindingsWithParseErrors(findings, errors) => {
    println(findings[0].element_path)
    println(errors[0].message)
  }
  ParseErrors(errors) => println(errors[0].message)
}
```

`audit_html` does no file I/O, so callers choose where HTML comes from and how results are presented. When its input contains `<!doctype` or `<html`, it uses the parser's full-document mode and includes document-only rules. Markup without either marker keeps the library's fragment-compatible behavior; use `audit_html_fragment` when auditing a component explicitly.

For a focused check, `available_rule_ids()` returns the accepted IDs in stable order and `audit_html_with_rules(html, enabled_rule_ids)` runs only the requested rules. `audit_html(html)` still runs every current rule. An empty selection runs no rules while retaining parser diagnostics; an unknown ID returns `ConfigurationError(UnknownRuleId(id))` rather than being ignored. Repeated IDs do not duplicate findings.

```moonbit nocheck
let selected = ["img-alt-missing", "heading-level-skipped"]

match @a11ytrace.audit_html_with_rules(html, selected) {
  Audited(Findings(findings)) => ()
  Audited(FindingsWithParseErrors(findings, errors)) => ()
  Audited(ParseErrors(errors)) => ()
  ConfigurationError(UnknownRuleId(rule_id)) =>
    // Correct the rule ID before running an audit.
    ()
}
```

`heading-level-skipped` is a suggestion for structural review, so it can be useful to select it independently in a content-build check. Selection does not change the caller-provided array, and all selected rules share one parsed DOM; findings remain in document order.

## HTML fragment audit

Components and template generators can audit local markup directly with `audit_html_fragment(fragment)`. `audit_html_fragment_with_rules(fragment, enabled_rule_ids)` has the same `ConfiguredAuditResult` and unknown-rule behavior as `audit_html_with_rules`.

```moonbit nocheck
let card = "<button></button><img src=\"report.png\">"

match @a11ytrace.audit_html_fragment_with_rules(
  card,
  ["button-name-missing", "img-alt-missing"],
) {
  Audited(result) => {
    let json = @a11ytrace.render_audit_json(result)
    // Consume the component findings in document order.
  }
  ConfigurationError(UnknownRuleId(rule_id)) => ()
}
```

Fragment parsing preserves the same deterministic paths, source locations when available, parser diagnostics, heading behavior, and template exclusion as normal auditing; in particular, the first native heading in a fragment may use any level. Name references are limited to the supplied markup: an `aria-labelledby` target or `<label for>` outside the fragment cannot be resolved and does not count as a name.

Document-only rules, including `document-title-missing` and `html-lang-missing`, never run through either fragment entry point. To check a page title and language, provide a full document:

```moonbit nocheck
///|
let page = "<!doctype html><html lang=\"en\"><head><title>Orders</title></head><body></body></html>"

///|
let result = @a11ytrace.audit_html(page)
```

The in-module consumer example is a separate MoonBit package that imports only this library's public API. Run it from the repository root with:

```text
moon run --target native examples/consumer
```

## JSON output

`render_audit_json(result : AuditResult) -> String` produces compact, parseable JSON using MoonBit's `moonbitlang/core/json` library. Every document has these fields, regardless of status:

- `status`: `"findings"`, `"findings_with_parse_errors"`, or `"parse_errors"`.
- `findings`: an array of objects with `rule_id`, `message`, `suggestion`, `element_path`, `line`, and `column`.
- `parse_diagnostics`: an array of objects with `code`, `message`, `line`, and `column`.

`line` and `column` are JSON numbers when supplied by the parser and JSON `null` when unavailable. A `"findings"` result with an empty findings array means only that these implemented static checks found nothing; it does not mean the page meets all accessibility standards.

Render only an `Audited` result. A rule-selection `ConfigurationError` is not serialized as an empty audit: report or correct `UnknownRuleId` before obtaining an `AuditResult`.

```moonbit nocheck
import {
  "moonbitlang/core/json" @json,
  "youyong5/a11ytrace" @a11ytrace,
}

match @a11ytrace.audit_html_with_rules(html, ["img-alt-missing"]) {
  Audited(result) => {
    let document = @a11ytrace.render_audit_json(result)
    let parsed = @json.parse(document)
    // Read the documented status/findings/parse_diagnostics fields from parsed.
  }
  ConfigurationError(UnknownRuleId(rule_id)) => ()
}
```

- A static-site generator can audit each rendered page before writing it.
- A documentation-site build can audit generated guide fragments.
- A frontend CI job can audit fixture or server-rendered HTML and fail on findings.

## Detailed static audit and manual review

`audit_html_detailed(html)` and `audit_html_fragment_detailed(fragment)` retain the same parser status and definite `findings` as the compatible audit APIs, while exposing `review_items` separately. A review item has `rule_id`, `reason`, `element_path`, `line`, and `column`; it means static markup alone cannot establish the result. `audit_html_detailed_with_rules` and `audit_html_fragment_detailed_with_rules` return `DetailedConfiguredAuditResult`, preserving the same explicit unknown-ID behavior while retaining review items. `render_detailed_audit_json(result)` adds a `review_items` array to the same stable JSON fields and status values. It does not serialize a rule-selection configuration error, because configuration errors must still be handled before an audit is run.

```moonbit nocheck
///|
let detailed = @a11ytrace.audit_html_fragment_detailed(
  "<div aria-hidden=\"true\"><button aria-label=\"Close\"></button></div>",
)

///|
let json = @a11ytrace.render_detailed_audit_json(detailed)
// detailed.findings: confirmed static signals
// detailed.review_items: browser/CSS review needed
```

## Native CLI example

The library remains the primary interface; the optional native executable in `cmd/a11ytrace` only reads one local HTML file and calls the public API above. Build or run it with MoonBit:

```text
moon run --target native cmd/a11ytrace -- examples/cli-example.html
moon run --target native cmd/a11ytrace -- examples/cli-example.html --format json
moon run --target native cmd/a11ytrace -- examples/cli-example.html --rules img-alt-missing,link-name-missing
moon run --target native cmd/a11ytrace -- --help
```

`--format json` writes only the JSON generated by `render_audit_json` to the executable's stdout. Text output displays a rule ID, element path, source location when known, message, and any parser diagnostics. Unknown rule IDs, malformed arguments, and file-read failures write an error instead of a report. The currently available public MoonBit APIs used by this small native example do not expose a portable process-exit setter, so those error paths currently exit with status 0. **Do not use this CLI's exit status alone as a CI success signal**; callers that need enforced exit codes should use the library API from their own build integration.

## Current rule and boundary

`img-alt-missing` reports an `<img>` that has no `alt` attribute. An explicit `alt=""` is accepted for decorative images, as is any non-empty `alt` value. The rule does not determine whether an image is decorative, whether alternative text is good, or whether a whole document conforms to WCAG.

`form-control-name-missing` reports unnamed `<input>`, `<select>`, and `<textarea>` controls, excluding hidden and button-like input types. It recognizes text-bearing labels, non-empty ARIA names, and `title` as a fallback; it does not implement the complete browser Accessible Name algorithm.

`link-name-missing` reports an `<a href>` without recognizable text, non-empty image alt text, ARIA name, or fallback title. It ignores script, style, and template text. It checks presence of a name, not whether the destination is described clearly; when no supported source is present, SVG-containing links are conservatively left unreported until SVG name sources are supported.

`button-name-missing` reports unnamed native `<button>`, `input[type="button"]`, and `input[type="image"]`; custom `role="button"` is outside this rule. It recognizes supported native text, image alt, value, ARIA, and title sources as appropriate, while leaving SVG-only native buttons unreported until SVG name sources are supported. It is a static name-presence check, not a WCAG conformance conclusion.

`heading-level-skipped` suggests reviewing a native heading that jumps down two or more levels from the preceding heading; the first heading may start at any level. `heading-name-missing` reports empty native headings unless supported text, image alt, or ARIA naming is present. Neither rule infers headings from visual styling or implements a complete browser Accessible Name algorithm.

`document-title-missing` and `html-lang-missing` apply only to complete-document input and require a non-empty head `<title>` and `<html lang>` respectively. `iframe-name-missing` accepts a non-empty `title`, `aria-label`, or resolvable text-bearing `aria-labelledby` target. `duplicate-id` reports later repeated non-empty IDs in the same audited input scope; duplicated IDs are deliberately not trusted for ARIA or label resolution.

`reference-target-invalid` reports missing or ambiguous non-empty targets used by `label[for]`, `aria-labelledby`, or `aria-describedby`; it does not call a separately named control “unnamed” merely because one of its references is invalid. `table-headers-invalid` checks that each `headers` token resolves to another unique `td` or `th` in the same nearest table. `area-alt-missing` requires non-empty `alt` on an `<area href>`; an area without `href` is outside that rule.

`body-aria-hidden` reports `aria-hidden="true"` on the body of a complete document. `multiple-main` is a static structural prompt for every main after the first in a complete document. When a document has multiple `<nav>` landmarks, `navigation-landmark-name-missing` reports a landmark without a supported static distinguishing name and `navigation-landmark-name-duplicate` reports a later repeated static name. These page-structure rules do not run for fragments.

`aria-hidden-focus-review` is a review item rather than a confirmed finding. It identifies a potentially focusable native element or explicit `tabindex` within an `aria-hidden="true"` element or ancestor; descendant `aria-hidden="false"` cannot undo an ancestor's hidden state. Disabled native controls are excluded, but `aria-disabled` alone is not. CSS, scripting, and browser focus behavior decide the final outcome. `aria-abstract-role` is a definite markup finding when a `role` attribute includes one of the ARIA 1.2 abstract role tokens; it intentionally does not claim that other role tokens are invalid.

All name-related checks share an ID and `label[for]` index built once from the recovered DOM. Multiple `aria-labelledby` references are supported, but missing, empty, duplicate, cyclic, or fragment-external references do not establish a name. A directly referenced static text node is accepted even if its markup has `hidden` or `aria-hidden`; A11yTrace does not compute rendered visibility or the browser name algorithm. These are static checks: CSS visibility, rendered focusability, script-created DOM, shadow DOM, and browser accessibility-tree behavior require manual or browser-based review.

For example, both rules can be reported from one fragment:

```moonbit nocheck
match @a11ytrace.audit_html("<img src=\"chart.svg\"><input placeholder=\"Email\">") {
  Findings(findings) => {
    // findings[0].rule_id == "img-alt-missing"
    // findings[1].rule_id == "form-control-name-missing"
  }
  FindingsWithParseErrors(findings, errors) => ()
  ParseErrors(errors) => ()
}
```

Current rules can be reported in document order:

```moonbit nocheck
match @a11ytrace.audit_html("<img src=\"chart.svg\"><input><a href=\"/details\"></a><button></button><h2>Section</h2><h4></h4>") {
  Findings(findings) => {
    // image, form, link, button, heading-level, and heading-name findings
  }
  FindingsWithParseErrors(findings, errors) => ()
  ParseErrors(errors) => ()
}
```

The parser uses HTML5-style recovery. Recoverable parser diagnostics produce `FindingsWithParseErrors`: the recovered DOM is still checked and diagnostics stay visible. `ParseErrors` is reserved for a parser failure that prevents a DOM audit. Findings include a deterministic CSS-style `element_path`; their optional line and column are source start-tag locations supplied by the parser, and remain absent when the parser has no source position.

See [RULES.md](RULES.md) for rule rationale and [REFERENCE-COMPARISON.md](REFERENCE-COMPARISON.md) for the scoped comparison with HTML-Validate, axe-core, and ACT references.

## License and attribution

A11yTrace's audit rules and library code are original work licensed under Apache-2.0 (see [LICENSE](LICENSE)). It depends on, but does not copy, `bobzhang/html_parser` 0.1.8 and the native CLI's `moonbitlang/async` 0.19.0; both dependencies are Apache-2.0 licensed.

HTML-Validate is an MIT-licensed reference project, and axe-core and W3C ACT Rules are reference material only; A11yTrace does not include or copy their source code.
