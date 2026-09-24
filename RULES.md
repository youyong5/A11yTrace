# Rules

## Rule selection

`available_rule_ids()` returns the stable IDs of the rules documented below. `audit_html_with_rules(html, enabled_rule_ids)` runs only those IDs, while `audit_html(html)` continues to run all current rules. An empty selection intentionally runs no rules but keeps any parser diagnostics. Duplicate IDs are treated as one selection, and an unknown ID is returned as `ConfigurationError(UnknownRuleId(id))`; it is never silently ignored.

All selected rules use one recovered DOM and report findings in document order. Rule selection does not implement or imply a conformance profile: in particular, `heading-level-skipped` remains an advisory structural-review rule.

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
