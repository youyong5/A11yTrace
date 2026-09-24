# Rules

## Rule selection

`available_rule_ids()` returns the stable IDs of the rules documented below. `audit_html_with_rules(html, enabled_rule_ids)` runs only those IDs, while `audit_html(html)` continues to run all current rules. An empty selection intentionally runs no rules but keeps any parser diagnostics. Duplicate IDs are treated as one selection, and an unknown ID is returned as `ConfigurationError(UnknownRuleId(id))`; it is never silently ignored.

All selected rules use one recovered DOM and report findings in document order. Rule selection does not implement or imply a conformance profile: in particular, `heading-level-skipped` remains an advisory structural-review rule.

## Rule directory

`available_rules()` returns the same stable built-in ordering as
`available_rule_ids()`, with copied `RuleMetadata` records. A record declares
its ID, concise purpose, category, input scope, result kind, reference URL, and
explicit static-analysis boundary. `rule_metadata(id)` queries one record.
`content_rule_ids()`, `document_rule_ids()`, and `review_rule_ids()` provide
fresh named selections without changing the existing explicit-ID API. The
directory is the code source of truth for valid IDs, not a second documentation
list.

## Input scope and shared context

`audit_html_fragment` always treats its input as a component-local fragment.
`audit_html` preserves the earlier fragment-compatible behavior for markup
without a complete-document marker; input containing `<!doctype` or `<html` is
parsed as a complete document and can run the document-only rules below. This
keeps page requirements from being applied to a standalone component. Use an
explicit `<!doctype html><html …>` document when page-level checks are wanted.

For every audited DOM, A11yTrace builds one shared context before evaluating
rules. It indexes non-empty IDs and `label[for]` associations, skipping inert
`template` contents. `aria-labelledby` accepts a whitespace-separated list:
any uniquely resolved, text-bearing target supplies a static name. Empty
values, missing targets, targets outside a supplied fragment, and duplicate-ID
targets do not supply a name. The implementation does not recursively follow
ARIA references, so cycles terminate safely and do not create a name. A
duplicate non-empty ID reports every occurrence after the first in the audited
input scope.

The context deliberately separates a target being uniquely present from it
having static text. This lets an existing but empty `aria-describedby` target
remain a valid relationship while an `aria-labelledby` target with no static
text fails to establish a name. Directly referenced static text is accepted
even when markup has `hidden` or `aria-hidden`, because this library does not
compute CSS or the browser accessibility tree. It does not yet implement
IDREF-derived text alternatives, ARIA name precedence, shadow-DOM lookup, or
the full Accessible Name and Description Computation.

Parser recovery still produces a recovered DOM and diagnostics. The context is
built from that recovered DOM; callers should review parser diagnostics before
treating reference-related results as authoritative.

## `document-title-missing`

For a complete document input, reports when the document head has no non-empty
`<title>`. An empty or whitespace-only `<title>` is reported at that element;
when no title exists the finding is attached to the document's `<html>`
element. The rule does not judge whether the title is descriptive, unique, or
supplied by a higher-level protocol such as an HTML email subject.

It is informed by [W3C ACT: HTML page has non-empty title](https://www.w3.org/WAI/standards-guidelines/act/rules/2779a5/)
and HTML-Validate's [empty-title](https://html-validate.org/rules/empty-title.html)
rule.

## `html-lang-missing`

For a complete document input, reports when the document `<html>` element lacks
a non-empty `lang` attribute. It checks presence and non-whitespace content
only; it does not validate language-tag syntax, determine language changes in
descendants, or infer a language from text.

It is informed by [WCAG Understanding Success Criterion 3.1.1: Language of
Page](https://www.w3.org/WAI/WCAG22/Understanding/language-of-page.html).

## `iframe-name-missing`

Reports an `<iframe>` without a non-empty `title`, `aria-label`, or resolvable
text-bearing `aria-labelledby` target. It checks static markup only. In
particular, it cannot determine CSS visibility, the accessibility-tree
inclusion exceptions in ACT (such as rendered behavior), or browser and
assistive-technology differences; review those cases manually.

The accepted static naming sources follow the [W3C ACT proposed iframe-name
rule](https://www.w3.org/WAI/standards-guidelines/act/rules/cae760/proposed/).

## `duplicate-id`

Reports each later occurrence of a non-empty `id` that duplicates an earlier
one in the same audited document or fragment input. The first occurrence is not
reported. Inert descendants of `<template>` are outside the input scope, so
their IDs are not compared with instantiated markup. This matches the need for
unique IDs within an active document scope, while keeping component-template
markup conservative.

The rule is informed by HTML-Validate's [no-dup-id](https://html-validate.org/rules/no-dup-id.html)
rule. It does not validate ID syntax; that is a separate concern.

## `reference-target-invalid`

Reports an element with a non-empty ID reference that has no unique target in
the current audited document or fragment. It covers `label[for]`,
`aria-labelledby`, and `aria-describedby`. Whitespace-separated ARIA IDREFs
are checked individually, but produce at most one finding on their source
element. Empty attributes contain no ID reference and are not reported by this
rule. A duplicate ID is treated as ambiguous, even though one or more matching
elements exist.

This is a relationship check, not an accessible-name verdict. For example, a
control with `aria-label="Email" aria-labelledby="valid missing"` still has a
static name through `aria-label`, while this rule reports the invalid
`aria-labelledby` relationship. Conversely, an existing empty
`aria-describedby` target is not reported here because this rule does not
judge description quality. `aria-controls` and `input[list]` are not included
yet; no target-type or runtime ownership claim is made.

The scope follows HTML-Validate's [no-missing-references](https://html-validate.org/rules/no-missing-references.html)
approach for these selected attributes, with conservative fragment-local
resolution.

## `table-headers-invalid`

Reports a `headers` token on a `td` or `th` when it does not resolve uniquely
to another `td` or `th` in the same nearest table. Missing IDs, duplicate IDs,
non-cell targets, targets in a nested or enclosing table, and self-references
are invalid. Empty `headers` contains no token and is not reported. A target is
not restricted to `<th>`: a `td` may participate in a complex association, as
in the ACT examples.

The check is structural and does not determine CSS visibility, semantic roles,
whether a cell is actually a useful header, or browser fallback header
assignment. It is informed by [W3C ACT rule a25f45](https://www.w3.org/WAI/standards-guidelines/act/rules/a25f45/)
and should not alone be represented as a WCAG conformance result.

## `area-alt-missing`

Reports an `<area>` with an `href` attribute when `alt` is missing, empty, or
whitespace-only. An `<area>` without `href` is not a clickable image-map link
for this rule and is not reported. The rule checks only the static `alt`
attribute; it does not decide whether the destination is clear, whether the
area belongs to a valid map, or whether browsers expose an out-of-map area in
their accessibility tree.

The rule is informed by the [W3C ACT link-name rule](https://www.w3.org/WAI/standards-guidelines/act/rules/c487ae/),
which uses `alt` for linked areas and records browser/assistive-technology
variation. It is a focused static signal, not a complete WCAG conclusion.

## Detailed results and review items

`audit_html_detailed` and `audit_html_fragment_detailed` return definite
findings, parser diagnostics, and `review_items` separately. A review item has
the same stable rule ID and source locator style as a finding, but its reason
states why static HTML alone is insufficient. `render_detailed_audit_json`
serializes `status`, `findings`, `parse_diagnostics`, and `review_items`.
Existing `AuditResult` APIs deliberately remain compatible and expose only
definite findings plus diagnostics. The corresponding detailed selection APIs
return `DetailedConfiguredAuditResult`, so selecting `aria-hidden-focus-review`
does not silently discard review items; unknown IDs remain explicit configuration
errors before parsing.

## `meta-refresh-delay`

For complete-document input only, reports `meta[http-equiv="refresh"]` when
the first semicolon-delimited `content` token is a supported decimal number
greater than zero. Attribute and token whitespace are trimmed and
`http-equiv` matching is case-insensitive. `0`, `0.0`, and `00.0` do not
report; malformed, signed, exponent, and policy-specific long-delay forms are
left outside this narrow static check. A fragment never receives this page
timing rule.

The behavior is calibrated against HTML-Validate's
[meta-refresh rule](https://html-validate.org/rules/meta-refresh.html), but
A11yTrace intentionally does not reproduce its refresh-loop or configurable
long-delay policy.

## `aria-state-value-invalid`

Reports one finding on an element when a non-empty value for one of this
explicitly supported set is invalid after trimming and ASCII case folding:

- Boolean: `aria-busy`, `aria-disabled`, `aria-modal`,
  `aria-multiline`, `aria-multiselectable`, `aria-readonly`, `aria-required`.
- True/false/undefined: `aria-expanded`, `aria-hidden`.
- Tristate: `aria-checked`, `aria-pressed`.
- Token sets: `aria-current` (`false`, `true`, `page`, `step`, `location`,
  `date`, `time`) and `aria-invalid` (`false`, `true`, `grammar`, `spelling`).

Empty values and every unlisted ARIA attribute are deliberately ignored. This
is not a general ARIA validator: it does not check attribute permission,
numeric, IDREF, token-list, role-dependent, SVG, or browser mapping semantics.
The scope is informed by [W3C ACT rule 6a7281](https://www.w3.org/WAI/standards-guidelines/act/rules/6a7281/),
which covers a broader set of ARIA values.

## `button-implicit-submit`

Provides a static best-practice prompt for a native `<button>` inside a form
when its `type` is missing or empty. In HTML that button defaults to submit,
which can make a non-submit action unexpectedly submit the form. Explicit
`type="button"` and `type="submit"` do not report, and neither do buttons
outside a form. Invalid type values, associated forms using the `form`
attribute, custom buttons, and the quality of a form's submission behavior are
outside this focused prompt.

The rule is informed by HTML-Validate's
[no-implicit-button-type](https://html-validate.org/rules/no-implicit-button-type.html)
rule. Its result kind is `StaticHint`; it is not presented as a WCAG violation.

## `body-aria-hidden`

For complete-document input only, reports `<body aria-hidden="true">`. Hiding
the document body can remove its contents from the accessibility tree. This is
a definite markup signal, but it does not establish the final rendered tree or
whether a script changes the attribute later. The rule is not run on fragments.

## `multiple-main`

For complete-document input only, reports every native `<main>` after the first
in document order as a structure prompt. It does not infer landmarks from
roles, evaluate nested browsing contexts, or declare WCAG conformance. It is
informed by HTML-Validate's document-oriented landmark checks.

## `navigation-landmark-name-missing` and `navigation-landmark-name-duplicate`

When a complete document has more than one native `<nav>`, each is checked for
a supported static distinguishing name from non-empty `aria-labelledby`,
`aria-label`, or `title`. An unnamed landmark is reported by
`navigation-landmark-name-missing`; a later repetition of the same static name
is reported by `navigation-landmark-name-duplicate`. SVG-only or runtime naming
sources become a review item rather than an asserted missing name. These rules
do not run on fragments and do not implement the browser Accessible Name
algorithm. They are informed by HTML-Validate's landmark-name guidance.

## `aria-hidden-focus-review`

This is a manual review item, not a confirmed WCAG violation. It marks an
element inside `aria-hidden="true"` (including a hidden ancestor) when it has
a supported potentially focusable native form/link/iframe behavior or a
non-empty explicit `tabindex`; `tabindex="-1"` is included because scripts can
focus it. A descendant `aria-hidden="false"` cannot cancel a hidden ancestor.
Native disabled controls are excluded, while `aria-disabled` alone is not.
Static HTML cannot determine CSS visibility, disabled state changed by script,
or actual sequential/programmatic focus behavior, so browsers must be checked.
This scope is informed by [W3C ACT rule 6cfa84](https://www.w3.org/WAI/standards-guidelines/act/rules/6cfa84/),
but the library deliberately reports review rather than claiming the ACT result.

## `aria-abstract-role`

Reports a non-empty `role` attribute that contains an ARIA 1.2 abstract role
token: `command`, `composite`, `input`, `landmark`, `range`, `roletype`,
`section`, `sectionhead`, `select`, `structure`, `widget`, or `window`.
Empty roles are ignored. This intentionally is not a general role-validity
rule: it does not reject concrete roles, validate fallback processing, or use
a partial whitelist to claim other roles are invalid. See the [WAI-ARIA 1.2
role taxonomy](https://www.w3.org/TR/wai-aria-1.2/#role_definitions).

## `img-alt-missing`

Reports an HTML `<img>` element that omits the `alt` attribute. The suggested repair is to add an appropriate `alt` attribute; `alt=""` is a valid explicit choice for a decorative image.

This rule is based on the guidance in the [W3C Images Tutorial](https://www.w3.org/WAI/tutorials/images/). It intentionally checks attribute presence only. It cannot judge an image's purpose or the quality of an alternative text, and it is not a conformance claim for a page or product.

## `form-control-name-missing`

Reports `<input>`, `<select>`, and `<textarea>` controls that have no recognizable accessible name. It excludes `input` elements whose type is `hidden`, `submit`, `reset`, `button`, or `image` in this first iteration.

The rule accepts non-empty text from a `<label for="control-id">`, a text-bearing wrapping `<label>` without `for`, non-empty `aria-label`, an `aria-labelledby` reference to at least one existing text-bearing element, or non-empty `title`. A wrapping label with `for` is only accepted when that value matches the descendant control's `id`. For multiple `aria-labelledby` IDs, each reference is examined and any valid text-bearing target supplies a name. Empty labels and ARIA values, missing or empty `aria-labelledby` targets, a bare `id`, and `placeholder` do not count. `title` is a fallback: a visible label is usually better.

This follows the [W3C Forms Labels Tutorial](https://www.w3.org/WAI/tutorials/forms/labels/). It is a focused static heuristic, not a complete implementation of the browser Accessible Name algorithm or a WCAG conformance determination.

## `link-name-missing`

Reports an `<a>` with an `href` attribute when it has no recognizable accessible name. It accepts non-empty descendant text, a descendant image with non-empty `alt`, non-empty `aria-label`, an `aria-labelledby` reference to an existing text-bearing element, or non-empty `title`. An anchor without `href`, empty or whitespace-only text, and an image with `alt=""` do not supply a link name.

The rule ignores text in `script`, `style`, and `template` descendants. It does not judge whether a link name describes its destination clearly. When none of the accepted HTML, image, ARIA, or title sources supplies a name, it does not yet reliably evaluate SVG naming sources; an anchor containing SVG is therefore conservatively left unreported rather than being asserted unnamed. Links with ordinary text or ARIA labels continue to be recognized normally. This is a focused static heuristic, not a complete implementation of the browser Accessible Name algorithm.

The rule is informed by the [W3C ACT Rule: Links have accessible name](https://www.w3.org/WAI/standards-guidelines/act/rules/c487ae/).

## `button-name-missing`

Reports native `<button>`, `input[type="button"]`, and `input[type="image"]` controls without a recognizable accessible name. It does not inspect custom `role="button"` elements.

For `<button>`, the rule accepts non-empty visible text, a descendant image with non-empty `alt`, non-empty `aria-label`, an `aria-labelledby` reference to an existing text-bearing element, or non-empty `title`. For `input[type="button"]`, it accepts non-empty `value`, ARIA naming, or `title`; whitespace-only and empty values do not count. For `input[type="image"]`, it accepts non-empty `alt`, ARIA naming, or `title`. `input[type="submit"]` and `input[type="reset"]` have browser default names and are not reported.

As with the link rule, text in `script`, `style`, and `template` descendants does not name a native button. SVG naming sources are not yet reliably evaluated, so SVG-only native buttons are conservatively left unreported. This is a static name-presence check, not a complete Accessible Name algorithm or a WCAG conformance determination.

The rule is informed by the [W3C ACT Rule: Button has accessible name](https://www.w3.org/WAI/standards-guidelines/act/rules/97a4e1/) and [W3C ACT Rule: Image button has accessible name](https://www.w3.org/WAI/standards-guidelines/act/rules/59796f/).

## `heading-level-skipped`

Walks native `h1` through `h6` in document order. The first heading may use any level. A later heading produces a suggestion only when it jumps downward by two or more levels from the preceding native heading, such as `h2` to `h4`. Moving upward, repeating a level, and moving down one level do not produce a finding.

The finding says “建议检查标题层级” because this is a structural review prompt, not a determination of WCAG non-conformance. It does not infer headings from visually styled text and does not inspect headings inside HTML template content.

## `heading-name-missing`

Reports empty native `h1` through `h6`. It accepts non-empty ordinary descendant text, a descendant image with non-empty `alt`, non-empty `aria-label`, or an `aria-labelledby` reference to an existing text-bearing element. Script, style, and template text does not count. As with link and button checks, SVG naming sources are not yet reliably evaluated, so SVG-only headings are conservatively left unreported.

These rules are informed by the [W3C Headings Tutorial](https://www.w3.org/WAI/tutorials/page-structure/headings/). They are focused static checks, not a complete browser Accessible Name algorithm or a WCAG conformance determination.
