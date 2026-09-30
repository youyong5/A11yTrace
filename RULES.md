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

## WCAG coverage and result kinds

The 68 stable IDs include confirmed static findings, structural hints, and
located manual-review items. `wcag_aa_criteria()` and `wcag_criterion(id)`
are the authoritative programmatic directory for WCAG 2.1/2.2 A/AA coverage;
`WCAG-COVERAGE.md` supplies the human-readable table and review procedures.
`audit_html_with_wcag_coverage(html)` returns the normal detailed audit plus a
copied directory. It never treats zero findings as a WCAG pass.

Manual-review items are emitted only when a relevant static marker exists
(for example a media element, explicit focus ordering, a custom interactive
role, a drag marker, or a password field). They identify what to test in a
browser rather than asserting a WCAG failure. CSS, JavaScript, media playback,
assistive-technology exposure, shadow DOM and cross-page consistency cannot be
proved from the parsed static input. `4.1.1 Parsing` appears only as a WCAG
2.1 historical entry and is explicitly removed from WCAG 2.2.

For release review, [RULE-INVENTORY.md](RULE-INVENTORY.md) lists all 68
selectable IDs separately as 38 confirmed-finding checks, 6 static hints, and
24 manual-review triggers, with their actual execution trigger and test
evidence. Those are result categories, not a count of automatically passed
WCAG success criteria.

New narrow static rules are intentionally bounded: selected ARIA required
property checks cover custom checkbox/switch/radio `aria-checked`, combobox
`aria-expanded`, and slider `aria-valuenow`; selected ARIA IDREF checks cover
`aria-activedescendant`, `aria-details`, `aria-controls`, and `aria-owns`.
The role-name checks cover custom button/link/radio, checkbox, combobox, slider,
progressbar, meter, image, dialog and alertdialog roles with the same limited static naming
sources as native-name rules. They do not claim full ARIA role validation or
browser name computation. `nested-interactive` only flags interactive
descendants of links or buttons; list rules only inspect direct children;
`table-header-name-missing` checks static header content, while the separate
`table-scope-invalid` rule checks only explicit invalid `th[scope]` keywords;
and `viewport-zoom-disabled` is a static resilience hint, not a WCAG verdict.

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
uniquely resolved targets are processed in source IDREF order. For each direct
target, the bounded static subset accepts non-empty `aria-label`, ordinary
text/descendant image `alt`, or fallback `title`. Empty values, missing
targets, targets outside a supplied fragment, and duplicate-ID targets do not
supply a name. A target's own `aria-labelledby` is deliberately not followed,
so self references and cycles terminate safely without inventing a name. A
duplicate non-empty ID reports every occurrence after the first in the audited
input scope.

The context deliberately separates a target being uniquely present from it
having a supported static name. This lets an existing but empty
`aria-describedby` target remain a valid relationship while an
`aria-labelledby` target with no supported name fails to establish a name.
The subset gives a usable `aria-labelledby` result precedence over `aria-label`
and the checked native/content/title fallbacks; all affected name rules share
that order. Directly referenced static text is accepted even when markup has
`hidden` or `aria-hidden`, because this library does not compute CSS or the
browser accessibility tree. It follows the relevant ordering ideas in [W3C
Accessible Name and Description Computation 1.2](https://www.w3.org/TR/accname-1.2/),
but does not implement generated content, CSS visibility, shadow DOM, slots,
embedded controls, host-language AAM details, or the full traversal algorithm.

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
- Tristate: `aria-checked` (except effective `role="radio"`, which permits
  only `true` or `false`), `aria-pressed`.
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

Reports a non-empty `role` attribute containing an ARIA 1.2 abstract token
only when its token list has no concrete WAI-ARIA 1.2 fallback. The abstract
tokens are `command`, `composite`, `input`, `landmark`, `range`, `roletype`,
`section`, `sectionhead`, `select`, `structure`, `widget`, and `window`.
Thus `role="widget checkbox"` uses the concrete `checkbox` fallback and is not
also reported as abstract. Empty roles are ignored. See the [WAI-ARIA 1.2 role
taxonomy](https://www.w3.org/TR/wai-aria-1.2/#role_definitions).

## `aria-attribute-undefined`

Reports an element carrying an `aria-*` attribute name that is not defined by
[WAI-ARIA 1.2](https://www.w3.org/TR/wai-aria-1.2/#state_prop_values). The
membership set includes the 1.2 additions such as `aria-description`,
`aria-braillelabel`, `aria-brailleroledescription`, `aria-colindextext`, and
`aria-rowindextext`, as well as the still-defined deprecated names
`aria-dropeffect` and `aria-grabbed`; those names are not falsely reported.

This is an attribute-name check only. It does not decide whether an otherwise
defined ARIA attribute is permitted for the element's role, whether its value
is valid, or whether an extension defined by another specification is
supported. Template contents are not audited. It applies equally to complete
documents and supplied fragments.

## `role-value-invalid`

Reports a non-empty `role` token list only when no token is a concrete
WAI-ARIA 1.2 role. It follows ordered fallback behavior: an unknown earlier
token does not make `role="future-role button"` invalid because `button` is a
usable fallback. Concrete roles also feed the existing selected ARIA
name/property checks, so `role="widget checkbox"` is checked as a checkbox.

If a list has no concrete fallback but includes an abstract role, only
`aria-abstract-role` is emitted, avoiding duplicate and contradictory role
findings. This intentionally validates the WAI-ARIA 1.2 core role vocabulary
only; host-language extensions, role permission, required descendants, and
the browser accessibility-tree mapping are outside scope. See [WAI-ARIA 1.2
role processing](https://www.w3.org/TR/wai-aria-1.2/#role_definitions).

## `role-button-name-missing`, `role-link-name-missing`, and `role-radio-name-missing`

Report an effective custom `role="button"`, `role="link"`, or `role="radio"` without a
supported static name. They accept non-empty descendant text, descendant image
`alt`, resolvable `aria-labelledby`, non-empty `aria-label`, and fallback
`title`. Whitespace-only content and `img[alt=""]` do not supply a name. The
effective role follows the same ordered concrete-role fallback as the rest of
the library, so `role="future-role radio"` is checked as a radio.

Native buttons, `<a href>`, and the selected native form controls are excluded
because their established name rules already own those elements; one element
does not receive both a native and custom-role name Finding. When an otherwise
unnamed custom role contains SVG, the rule emits a ReviewItem rather than a
Finding because SVG/browser name sources are not reliably computed. This is a
bounded static presence check informed by [Accessible Name and Description
Computation 1.2](https://www.w3.org/TR/accname-1.2/), not a complete browser
AccName implementation or WCAG conformance conclusion.

## `aria-required-property-missing` and `aria-state-value-invalid`

`aria-required-property-missing` checks only selected effective custom roles:
`checkbox`, `switch`, and `radio` require `aria-checked`; `combobox` requires
`aria-expanded`; and `slider` requires `aria-valuenow`. A native
`<input type="radio">` is not reported merely because it uses its HTML checked
state instead of an ARIA attribute, including when it redundantly carries
`role="radio"`.

`aria-state-value-invalid` validates the listed static state tokens and emits
at most one state-value Finding for an element. `aria-checked="mixed"` is
accepted for the general tristate cases already supported by this bounded rule,
but it is invalid for an effective `role="radio"`; only `true` and `false` are
accepted there. These are static markup checks: they do not verify a radio
group's keyboard behavior, mutual exclusion, or browser accessibility-tree
state. See [WAI-ARIA 1.2 radio](https://www.w3.org/TR/wai-aria-1.2/#radio).

## `table-scope-invalid`

Reports an explicit `scope` attribute on a `<th>` when the trimmed,
case-insensitive value is not `row`, `col`, `rowgroup`, or `colgroup`. It does
not report a missing `scope` attribute, and it ignores `scope` placed on a
`<td>`. The rule applies to documents and fragments and skips inert template
contents. It is a definite HTML markup-value finding, but not by itself a
determination that WCAG 1.3.1 fails: HTML assigns an invalid `scope` value the
Auto state and the resulting association still depends on table context.

The rule does not infer the implicit association algorithm or verify whether a
`rowgroup` or `colgroup` is contextually anchored; those require fuller table
structure analysis. It follows the [HTML `th` scope
keywords](https://html.spec.whatwg.org/multipage/tables.html#attr-th-scope).

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
