# A11yTrace

A11yTrace is a small, pure MoonBit library for statically checking HTML accessibility rules.

## Current development checkout

This checkout provides 73 selectable built-in IDs, deliberately separated into
43 confirmed Finding checks, 6 static hints, and 24 ReviewItem triggers. That
directory is not an automatic WCAG-conformance count. The public WCAG directory
contains 55 current WCAG 2.2 A/AA criteria plus historical 4.1.1 (removed in
2.2): 9 are partially checked from static HTML, 33 have manual-review steps,
and 13 are not assessed. Zero findings never means WCAG conformance.

For detailed JSON, `assessment` is `findings`, `needs_review`,
`no_static_findings`, or `parse_errors`; a report with only ReviewItems is
explicitly `needs_review`.

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

## Rule directory and combinations

`available_rules() -> Array[RuleMetadata]` is the single built-in rule directory behind `available_rule_ids()`. Each copied record has `id`, `summary`, `category`, `scope` (`Document`, `Fragment`, or `DocumentOrFragment`), `result_kind` (`ConfirmedFinding`, `StaticHint`, or `ManualReview`), `reference_url`, and `boundary`. Use `rule_metadata(id)` for one record. `content_rule_ids()`, `document_rule_ids()`, and `review_rule_ids()` return fresh, named selections; callers can still pass any IDs to the established selection APIs.

```moonbit nocheck
match @a11ytrace.rule_metadata("aria-hidden-focus-review") {
  Some(rule) => println(rule.boundary)
  None => ()
}
let page_rules = @a11ytrace.document_rule_ids()
```

## WCAG 2.1/2.2 coverage directory

The library exposes a version-aware A/AA criterion directory without turning
an audit into a conformance claim. `wcag_aa_criteria()` returns copied
`WcagCriterion` records with `id`, `title`, `level`, `in_wcag21`, `in_wcag22`,
`coverage_status`, mapped `rule_ids`, concrete `review_steps`, and an official
reference URL. `wcag_criterion(id)` looks up one record. The directory retains
historical `4.1.1` as `RemovedInWcag22`; it must not be treated as a WCAG 2.2
criterion.

```moonbit nocheck
let report = @a11ytrace.audit_html_with_wcag_coverage(page_html)
// report.audit.findings are static signals.
// report.audit.review_items need browser/CSS/runtime verification.
// report.criteria describes coverage, never whether the page passed a criterion.
match @a11ytrace.wcag_criterion("2.4.11") {
  Some(criterion) => println(criterion.review_steps)
  None => ()
}
```

See [WCAG-COVERAGE.md](WCAG-COVERAGE.md) for every WCAG 2.1/2.2 A/AA
criterion, the version difference, mappings, and the required review step.
`render_wcag_audit_json(report)` produces `{"audit": {…detailed result…},
"criteria": […coverage records…]}`. Each criterion uses the stable
`coverage_status` strings `partial_automatic`, `manual_review`,
`not_assessed`, or `removed_in_wcag22`; none is a pass status.
The current directory has 56 records: 9 partial-automatic, 33 manual-review,
13 not-assessed, and the one WCAG 2.1 historical record removed in WCAG 2.2.

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

`audit_html_detailed(html)` and `audit_html_fragment_detailed(fragment)` retain the same parser status and definite `findings` as the compatible audit APIs, while exposing `review_items` separately. A review item has `rule_id`, `reason`, `element_path`, `line`, and `column`; it means static markup alone cannot establish the result. `audit_html_detailed_with_rules` and `audit_html_fragment_detailed_with_rules` return `DetailedConfiguredAuditResult`, preserving the same explicit unknown-ID behavior while retaining review items. `render_detailed_audit_json(result)` retains its existing fields and adds `assessment`: `findings`, `needs_review`, `no_static_findings`, or `parse_errors`. In particular, a report containing only review items is `needs_review`, never a pass. It does not serialize a rule-selection configuration error, because configuration errors must still be handled before an audit is run.

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
moon run --target native cmd/a11ytrace -- examples/review-only.html --format detailed-json
moon run --target native cmd/a11ytrace -- examples/cli-example.html --rules img-alt-missing,link-name-missing
moon run --target native cmd/a11ytrace -- --help
```

`--format json` remains compatible and writes only `render_audit_json` output to stdout; it intentionally does not contain review items. `--format detailed-json` writes only `render_detailed_audit_json` output, including `review_items`. A document with only review items has an empty `findings` array, which means neither “fully passed” nor that browser review is unnecessary. Text output displays a rule ID, element path, source location when known, message, and any parser diagnostics. Unknown rule IDs, malformed arguments, and file-read failures write an error instead of a report. The currently available public MoonBit APIs used by this small native example do not expose a portable process-exit setter, so those error paths currently exit with status 0. **Do not use this CLI's exit status alone as a CI success signal**; callers that need enforced exit codes should use the library API from their own build integration.

## Current rule and boundary

The rule directory now has 73 independently selectable checks and review
triggers. In addition to the rules below, it covers selected ARIA required
properties and ID relationships; static names for selected ARIA widgets;
direct list/definition-list structure; empty table headers; unsafe viewport
zoom tokens; and located media, keyboard, focus, target-size, dragging,
pointer, motion, form, authentication, status-message, language, contrast and
sequence review markers. These manual-review items are deliberately separate
from confirmed findings.

`img-alt-missing` reports an `<img>` that has no `alt` attribute. An explicit `alt=""` is accepted for decorative images, as is any non-empty `alt` value. The rule does not determine whether an image is decorative, whether alternative text is good, or whether a whole document conforms to WCAG.

`form-control-name-missing` reports unnamed `<input>`, `<select>`, and `<textarea>` controls, excluding hidden and button-like input types. It recognizes text-bearing labels, non-empty ARIA names, and `title` as a fallback; it does not implement the complete browser Accessible Name algorithm.

`link-name-missing` reports an `<a href>` without recognizable text, non-empty image alt text, ARIA name, or fallback title. It ignores script, style, and template text. It checks presence of a name, not whether the destination is described clearly; when no supported source is present, SVG-containing links are conservatively left unreported until SVG name sources are supported.

`button-name-missing` reports unnamed native `<button>`, `input[type="button"]`, and `input[type="image"]`; custom `role="button"` is outside this rule. It recognizes supported native text, image alt, value, ARIA, and title sources as appropriate, while leaving SVG-only native buttons unreported until SVG name sources are supported. It is a static name-presence check, not a WCAG conformance conclusion.

`heading-level-skipped` suggests reviewing a native heading that jumps down two or more levels from the preceding heading; the first heading may start at any level. `heading-name-missing` reports empty native headings unless supported text, image alt, or ARIA naming is present. Neither rule infers headings from visual styling or implements a complete browser Accessible Name algorithm.

`document-title-missing` and `html-lang-missing` apply only to complete-document input and require a non-empty head `<title>` and `<html lang>` respectively. `iframe-name-missing` accepts a non-empty `title`, `aria-label`, or resolvable text-bearing `aria-labelledby` target. `duplicate-id` reports later repeated non-empty IDs in the same audited input scope; duplicated IDs are deliberately not trusted for ARIA or label resolution.

`reference-target-invalid` reports missing or ambiguous non-empty targets used by `label[for]`, `aria-labelledby`, or `aria-describedby`; it does not call a separately named control “unnamed” merely because one of its references is invalid. `label-for-target-not-labelable` separately reports only a unique `label[for]` target that is a known non-labelable built-in HTML element, such as a `div` or hidden input; it accepts button, non-hidden input, meter, output, progress, select, and textarea, and skips custom elements because form association is not statically knowable. `label-multiple-labelable-descendants` reports each label once when it contains two or more known built-in labelable descendants; explicit `for` does not exempt a second descendant, while hidden inputs, template contents, and unknown custom elements are not counted. These are definite HTML association/content-model findings, not per-instance WCAG conclusions. `table-headers-invalid` checks that each `headers` token resolves to another unique `td` or `th` in the same nearest table. `area-alt-missing` requires non-empty `alt` on an `<area href>`; an area without `href` is outside that rule.

`body-aria-hidden` reports `aria-hidden="true"` on the body of a complete document. `multiple-main` is a static structural prompt for every main after the first in a complete document. When a document has multiple `<nav>` landmarks, `navigation-landmark-name-missing` reports a landmark without a supported static distinguishing name and `navigation-landmark-name-duplicate` reports a later repeated static name. These page-structure rules do not run for fragments.

`aria-hidden-focus-review` is a review item rather than a confirmed finding. It identifies a potentially focusable native element or explicit `tabindex` within an `aria-hidden="true"` element or ancestor; descendant `aria-hidden="false"` cannot undo an ancestor's hidden state. Disabled native controls are excluded, but `aria-disabled` alone is not. CSS, scripting, and browser focus behavior decide the final outcome. `aria-abstract-role` reports an abstract ARIA 1.2 role only when no concrete fallback token exists. `role-value-invalid` reports a non-empty role list only when it has no concrete WAI-ARIA 1.2 fallback, so `role="future-role button"` is accepted and `role="widget checkbox"` is checked as a checkbox without a second abstract-role finding.

`role-button-name-missing`, `role-link-name-missing`, and `role-radio-name-missing` check effective custom `role="button"`, `role="link"`, and `role="radio"` elements for the same bounded static sources as other name rules: descendant text, non-empty image alt, `aria-labelledby`, `aria-label`, and title. Native buttons, `<a href>`, and form controls are excluded when an existing native name rule already owns the element, avoiding duplicate name findings. SVG-only cases become ReviewItems rather than definite missing-name findings. Custom radios also require `aria-checked`; native `input[type="radio"]` is not reported for using its HTML state instead.

`role-textbox-name-missing` and `role-searchbox-name-missing` check effective custom `role="textbox"` and `role="searchbox"` only for author-provided static names: a supported local `aria-labelledby` target, non-empty `aria-label`, or fallback title. They deliberately do not treat ordinary descendants, `contenteditable` text, `placeholder`, or `aria-placeholder` as names. Native `<input>` and `<textarea>` remain under `form-control-name-missing`. An `aria-labelledby` target containing SVG without another supported static source becomes a ReviewItem because this bounded parser does not compute SVG/browser naming.

`meta-refresh-delay` applies only to complete documents and reports a `meta[http-equiv="refresh"]` with a supported numeric delay greater than zero. It does not check refresh loops, long-delay exceptions, malformed delay syntax, or runtime changes. `aria-required-property-missing` also checks effective custom `role="scrollbar"` for both `aria-controls` and `aria-valuenow`, reporting the missing property or the two missing properties in one Finding; an invalid supplied controls target remains an `aria-idref-invalid` issue. `aria-range-value-invalid` checks explicit finite numeric `aria-valuemin`, `aria-valuemax`, and `aria-valuenow` on custom effective slider/scrollbar roles, uses 0/100 only for omitted min/max, and keeps omitted `aria-valuenow` under the required-property rule. It does not apply to spinbutton, progressbar, or native form controls. `aria-attribute-undefined` checks only whether an `aria-*` name belongs to WAI-ARIA 1.2, including 1.2 additions and deprecated-but-defined names; it does not validate permission or values. `aria-state-value-invalid` checks only these explicitly listed static values: boolean `aria-busy`, `aria-disabled`, `aria-modal`, `aria-multiline`, `aria-multiselectable`, `aria-readonly`, and `aria-required`; true/false/undefined `aria-expanded` and `aria-hidden`; tristate `aria-checked` (except effective `role="radio"`, which accepts only true/false) and `aria-pressed`; and token values for `aria-current` and `aria-invalid`. `table-scope-invalid` only reports an explicit invalid `th[scope]` keyword, never an omitted scope or a `td[scope]`; it does not infer table associations.

`button-implicit-submit` is a static best-practice prompt, not an accessibility violation finding: it reports a native `<button>` inside a `<form>` only when `type` is missing or empty, because it defaults to submit. Explicit `type="submit"` and `type="button"`, buttons outside forms, invalid type values, and form-owner behavior through a `form` attribute are outside its narrow scope.

All name-related checks share an ID and `label[for]` index built once from the recovered DOM. Multiple `aria-labelledby` references are processed in IDREF order; a uniquely resolved direct target can contribute non-empty `aria-label`, text/descendant image alt, or fallback title. A usable result takes precedence over `aria-label` and native/content/title fallbacks on the named element. Missing, empty, duplicate, or fragment-external references do not establish a name. Cyclic and self-reference graphs are never followed recursively, though a directly referenced node can still contribute one of its own supported static sources. A directly referenced static text node is accepted even if its markup has `hidden` or `aria-hidden`; A11yTrace does not compute rendered visibility or the browser name algorithm. This is informed by [Accessible Name and Description Computation 1.2](https://www.w3.org/TR/accname-1.2/), not a complete implementation: CSS generated/hidden content, SVG, shadow DOM, slots, embedded controls, script-created DOM, and browser accessibility-tree behavior require manual or browser-based review.

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
The release-review [RULE-INVENTORY.md](RULE-INVENTORY.md) lists every selectable
ID, its actual outcome type and trigger, WCAG/practice mapping, source location,
and named test evidence.

## License and attribution

A11yTrace's audit rules and library code are original work licensed under Apache-2.0 (see [LICENSE](LICENSE)). It depends on, but does not copy, `bobzhang/html_parser` 0.1.8 and the native CLI's `moonbitlang/async` 0.19.0; both dependencies are Apache-2.0 licensed.

HTML-Validate is an MIT-licensed reference project, and axe-core and W3C ACT Rules are reference material only; A11yTrace does not include or copy their source code.
