# A11yTrace

A11yTrace is a small, pure MoonBit library for statically checking HTML accessibility rules.

## Release 0.5.0

The published 0.5.0 release provides 80 selectable built-in IDs. This
development checkout adds `img-text-alternative-missing` and
`autocomplete-value-invalid`, for 82 IDs, deliberately separated into 51 confirmed Finding checks, 7 static hints, and
24 ReviewItem triggers. That directory is not an automatic WCAG-conformance count. The public WCAG directory
contains 55 current WCAG 2.2 A/AA criteria plus historical 4.1.1 (removed in
2.2): 11 are partially checked from static HTML, 31 have manual-review steps,
and 13 are not assessed. Zero findings never means WCAG conformance.

For detailed JSON, `assessment` is `findings`, `needs_review`,
`no_static_findings`, or `parse_errors`; a report with only ReviewItems is
explicitly `needs_review`.

## Install from Mooncakes

From a new MoonBit project, install the release and import its public module
name:

```text
moon new a11ytrace-demo
cd a11ytrace-demo
moon add youyong5/a11ytrace@0.5.0
```

Add this import to the generated `cmd/main/moon.pkg` before its `pkgtype`
declaration:

```moonbit nocheck
///|
import {
  "youyong5/a11ytrace",
}
```

Then replace `cmd/main/main.mbt` with this minimal audit and run it:

```moonbit nocheck
///|
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
The current directory has 56 records: 11 partial-automatic, 31 manual-review,
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

The rule directory now has 82 independently selectable checks and review
triggers. In addition to the rules below, it covers selected ARIA required
properties and ID relationships; static names for selected ARIA widgets;
direct list/definition-list structure; empty table headers; unsafe viewport
zoom tokens; and located media, keyboard, focus, target-size, dragging,
pointer, motion, form, authentication, status-message, language, contrast and
sequence review markers. These manual-review items are deliberately separate
from confirmed findings.

The next-version `aria-checked-role-incompatible` rule reports `aria-checked`
only when an explicit effective WAI-ARIA 1.2 role does not support that state;
it leaves native host-language semantics and all other ARIA-property permission
tables outside its deliberately narrow scope. `listitem-orphan` reports a
recovered `<li>` whose direct parent is not `ul`, `ol`, or `menu`; parser
recovery can change malformed source structure. `fieldset-legend-missing` is a
static grouping prompt when a fieldset has more than one known native labelable
descendant but no non-empty first `<legend>`; it is not an asserted WCAG
failure and does not infer custom form association.

`aria-role-attribute-incompatible` adds a separate, deliberately small
WAI-ARIA 1.2 role/property table. It checks selected attributes on an
effective explicit role, including `searchbox` inheritance from `textbox`,
`treegrid` inheritance from `grid`, and the explicitly name-prohibited
`emphasis` role. It leaves `aria-checked` to the established specialized rule,
accepts global relationships such as `aria-describedby`, skips native form
controls and unknown roles, and does not implement the full ARIA or ARIA-in-HTML
permission matrix. See [ARIA-ROLE-ATTRIBUTE-TABLE.md](ARIA-ROLE-ATTRIBUTE-TABLE.md)
for each modeled row and excluded role.

`img-alt-missing` reports an `<img>` that has no `alt` attribute. An explicit `alt=""` is accepted for decorative images, as is any non-empty `alt` value. The rule does not determine whether an image is decorative, whether alternative text is good, or whether a whole document conforms to WCAG.

`img-text-alternative-missing` is a separate static semantic check for `<img>`. It accepts non-empty `alt`, `aria-label`, a unique supported `aria-labelledby` target, or fallback `title`; it accepts an exactly empty `alt`, effective `role="none"`/`role="presentation"`, and `aria-hidden="true"` as static decoration/exclusion signals. Whitespace-only `alt` is not treated as decorative. Explicit `role="img"` with an empty name is reported. Focusability or ARIA properties prevent the rule from treating a presentational role as decorative. An unmodeled explicit role becomes a ReviewItem, not a Finding. In the default audit, a bare image that omits `alt` keeps the legacy `img-alt-missing` Finding rather than receiving two equivalent findings. Neither image rule judges whether text accurately serves the image's purpose, so neither alone proves a WCAG 1.1.1 outcome.

`form-control-name-missing` reports unnamed `<input>`, `<select>`, and `<textarea>` controls, excluding hidden and button-like input types. It recognizes text-bearing labels, non-empty ARIA names, direct SVG `<title>` in supported static sources, and `title` as a fallback; unresolved SVG/browser sources remain review outcomes. It does not implement the complete browser Accessible Name algorithm.

`autocomplete-value-invalid` validates the syntax and order of an existing, non-empty HTML `autocomplete` token list on supported `<input>`, `<select>`, and `<textarea>` controls. It accepts ASCII-whitespace-separated, case-insensitive optional `section-*`, `shipping`/`billing`, a contact hint only before an email/IMPP/telephone field, one known field token, and final `webauthn` on input/textarea. It skips lone `on`/`off`, hidden/fixed-value input types, and disabled controls. It does not decide a control's real data purpose, control/type suitability, CSS/runtime applicability, or WCAG conformance.

`link-name-missing` reports an `<a href>` without recognizable text, non-empty image alt text, direct SVG `<title>`, ARIA name, or fallback title. It ignores script, style, and template text. It checks presence of a name, not whether the destination is described clearly; unresolved SVG sources become ReviewItems rather than a definite missing-name Finding.

`button-name-missing` reports unnamed native `<button>`, `input[type="button"]`, and `input[type="image"]`; custom `role="button"` is outside this rule. It recognizes supported native text, image alt, direct SVG `<title>`, value, ARIA, and title sources as appropriate; unresolved SVG sources become ReviewItems. It is a static name-presence check, not a WCAG conformance conclusion.

`heading-level-skipped` suggests reviewing a native heading that jumps down two or more levels from the preceding heading; the first heading may start at any level. `heading-name-missing` reports empty native headings unless supported text, image alt, direct SVG `<title>`, or ARIA naming is present; unresolved SVG sources become ReviewItems. Neither rule infers headings from visual styling or implements a complete browser Accessible Name algorithm.

`document-title-missing` and `html-lang-missing` apply only to complete-document input and require a non-empty head `<title>` and `<html lang>` respectively. `html-lang-invalid` separately checks a non-empty document `html[lang]` for a known IANA primary language subtag; it does not duplicate an empty-value Finding. `element-lang-invalid` checks a non-empty explicit `lang` in a complete document's recovered body subtree or supplied fragment. Both accept known-primary values such as `EN`, `zh-Hans`, `fr-CH`, and even loose later subtags such as `de-hello`; they reject an unknown primary or obvious empty/non-alphanumeric separator. They do not infer the language of text, flat-tree scope, CSS visibility, inheritance, or WCAG language exceptions, so `language-of-parts-review` remains necessary. See [LANGUAGE-SUBTAGS.md](LANGUAGE-SUBTAGS.md) for the fixed IANA data, update record, and limitations. `iframe-name-missing` accepts a non-empty `title`, `aria-label`, or supported direct-target `aria-labelledby` source, including direct SVG `<title>`. `duplicate-id` reports later repeated non-empty IDs in the same audited input scope; duplicated IDs are deliberately not trusted for ARIA or label resolution.

`reference-target-invalid` reports missing or ambiguous non-empty targets used by `label[for]`, `aria-labelledby`, or `aria-describedby`; it does not call a separately named control “unnamed” merely because one of its references is invalid. `label-for-target-not-labelable` separately reports only a unique `label[for]` target that is a known non-labelable built-in HTML element, such as a `div` or hidden input; it accepts button, non-hidden input, meter, output, progress, select, and textarea, and skips custom elements because form association is not statically knowable. `label-multiple-labelable-descendants` reports each label once when it contains two or more known built-in labelable descendants; explicit `for` does not exempt a second descendant, while hidden inputs, template contents, and unknown custom elements are not counted. These are definite HTML association/content-model findings, not per-instance WCAG conclusions. `table-headers-invalid` checks that each `headers` token resolves to another unique `td` or `th` in the same nearest table. `area-alt-missing` requires non-empty `alt` on an `<area href>`; an area without `href` is outside that rule.

`body-aria-hidden` reports `aria-hidden="true"` on the body of a complete document. `multiple-main` is a static structural prompt for every main after the first in a complete document. When a document has multiple `<nav>` landmarks, `navigation-landmark-name-missing` reports a landmark without a supported static distinguishing name and `navigation-landmark-name-duplicate` reports a later repeated static name. These page-structure rules do not run for fragments.

`aria-hidden-focus-review` is a review item rather than a confirmed finding. It identifies a potentially focusable native element or explicit `tabindex` within an `aria-hidden="true"` element or ancestor; descendant `aria-hidden="false"` cannot undo an ancestor's hidden state. Disabled native controls are excluded, but `aria-disabled` alone is not. CSS, scripting, and browser focus behavior decide the final outcome. `aria-abstract-role` reports an abstract ARIA 1.2 role only when no concrete fallback token exists. `role-value-invalid` reports a non-empty role list only when it has no concrete WAI-ARIA 1.2 fallback, so `role="future-role button"` is accepted and `role="widget checkbox"` is checked as a checkbox without a second abstract-role finding.

`role-button-name-missing`, `role-link-name-missing`, and `role-radio-name-missing` check effective custom `role="button"`, `role="link"`, and `role="radio"` elements for the same bounded static sources as other name rules: descendant text, non-empty image alt, a direct SVG `<title>`, `aria-labelledby`, `aria-label`, and title. Native buttons, `<a href>`, and form controls are excluded when an existing native name rule already owns the element, avoiding duplicate name findings. Unresolved SVG-only cases become ReviewItems rather than definite missing-name findings. Custom radios also require `aria-checked`; native `input[type="radio"]` is not reported for using its HTML state instead.

`role-textbox-name-missing` and `role-searchbox-name-missing` check effective custom `role="textbox"` and `role="searchbox"` only for author-provided static names: a supported local `aria-labelledby` target, non-empty `aria-label`, or fallback title. They deliberately do not treat ordinary descendants, `contenteditable` text, `placeholder`, or `aria-placeholder` as names. Native `<input>` and `<textarea>` remain under `form-control-name-missing`. A direct SVG `<title>` in a supported IDREF target is accepted; unresolved SVG sources become ReviewItems because this bounded parser does not compute browser SVG naming.

`meta-refresh-delay` applies only to complete documents and reports a `meta[http-equiv="refresh"]` with a supported numeric delay greater than zero. It does not check refresh loops, long-delay exceptions, malformed delay syntax, or runtime changes. `aria-required-property-missing` also checks effective custom `role="scrollbar"` for both `aria-controls` and `aria-valuenow`, reporting the missing property or the two missing properties in one Finding; an invalid supplied controls target remains an `aria-idref-invalid` issue. `aria-range-value-invalid` checks explicit finite numeric `aria-valuemin`, `aria-valuemax`, and `aria-valuenow` on custom effective slider/scrollbar roles, uses 0/100 only for omitted min/max, and keeps omitted `aria-valuenow` under the required-property rule. It does not apply to spinbutton, progressbar, or native form controls. `aria-required-context-role` checks only its published WAI-ARIA 1.2 role/context pairs using recovered DOM ancestry and one unique valid local `aria-owns` owner; root-level, hidden, presentational, ambiguous, and fragment-external relationships are deliberately not asserted. See [ARIA-REQUIRED-CONTEXT-TABLE.md](ARIA-REQUIRED-CONTEXT-TABLE.md). `aria-attribute-undefined` checks only whether an `aria-*` name belongs to WAI-ARIA 1.2, including 1.2 additions and deprecated-but-defined names; it does not validate permission or values. `aria-state-value-invalid` checks only these explicitly listed static values: boolean `aria-busy`, `aria-disabled`, `aria-modal`, `aria-multiline`, `aria-multiselectable`, `aria-readonly`, and `aria-required`; true/false/undefined `aria-expanded` and `aria-hidden`; tristate `aria-checked` (except effective `role="radio"`, which accepts only true/false) and `aria-pressed`; and token values for `aria-current` and `aria-invalid`. `table-scope-invalid` only reports an explicit invalid `th[scope]` keyword, never an omitted scope or a `td[scope]`; it does not infer table associations.

`button-implicit-submit` is a static best-practice prompt, not an accessibility violation finding: it reports a native `<button>` inside a `<form>` only when `type` is missing or empty, because it defaults to submit. Explicit `type="submit"` and `type="button"`, buttons outside forms, invalid type values, and form-owner behavior through a `form` attribute are outside its narrow scope.

All name-related checks share an ID and `label[for]` index built once from the recovered DOM. Multiple `aria-labelledby` references are processed in IDREF order. A unique target contributes only its direct non-empty `aria-label`, text/descendant image alt, direct SVG `<title>`, or fallback title; because the target is already being traversed, its own `aria-labelledby` is not followed. A usable `aria-labelledby` result takes precedence over `aria-label` and native/content/title fallbacks on the named element. Missing, empty, duplicate, or fragment-external references do not establish a name. Self references can contribute a direct author source; cycles stop safely. Directly referenced static text is accepted even when markup has `hidden` or `aria-hidden`; A11yTrace does not compute rendered visibility or the browser name algorithm. This is informed by [Accessible Name and Description Computation 1.2](https://www.w3.org/TR/accname-1.2/), [HTML-AAM](https://www.w3.org/TR/html-aam-1.0/), and [SVG-AAM](https://www.w3.org/TR/svg-aam-1.0/), not a complete implementation: CSS generated/hidden content, SVG `<desc>`, shadow DOM, slots, embedded controls, script-created DOM, and browser accessibility-tree behavior can remain ReviewItems or require browser-based review.

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
