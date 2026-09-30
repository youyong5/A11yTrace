# WCAG 2.1/2.2 A/AA coverage directory

This directory is a capability map, not a conformance report. A finding is a
static signal; an empty finding list does **not** mean that a success criterion
passes. `wcag_aa_criteria()` exposes the same version-aware records to MoonBit
callers. Every criterion links to the [official WCAG 2.2 Recommendation](https://www.w3.org/TR/WCAG22/);
the [WCAG 2.1 additions](https://www.w3.org/WAI/standards-guidelines/wcag/new-in-21/)
and [WCAG 2.2 additions/removal](https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/)
define the version differences.

Status meanings: **Partial automatic** has one or more narrow static rules and
still needs the listed human check; **Manual review** emits a located review
item when static markup contains a relevant trigger, or needs the listed
procedure; **Not assessed** has no reliable static trigger in this release.
`4.1.1` is retained only as WCAG 2.1 history: it was removed in WCAG 2.2.

Current directory totals: **56** records = **10 partial automatic**, **32
manual review**, **13 not assessed**, and **1 removed in WCAG 2.2**. The 55
records marked present in WCAG 2.2 are the current A/AA set; the removed record
is never included as a current WCAG 2.2 requirement.

| SC | Level | 2.1 / 2.2 | Status | A11yTrace rules or review procedure |
| --- | --- | --- | --- | --- |
| 1.1.1 Non-text Content | A | both | Partial automatic | `img-alt-missing`, `img-text-alternative-missing`, `area-alt-missing`; review image purpose and whether any alternative serves that purpose. |
| 1.2.1–1.2.5 Time-based Media | A/AA | both | Manual review | For each audio/video asset, play it; verify alternatives, captions and audio description. |
| 1.3.1 Info and Relationships | A | both | Partial automatic | Table/header and heading checks; review all visual relationships. |
| 1.3.2 Meaningful Sequence | A | both | Manual review | `meaningful-sequence-review`; compare DOM and rendered order. |
| 1.3.3 Sensory Characteristics | A | both | Not assessed | Inspect instructions for shape/color/location/sound-only cues. |
| 1.3.4 Orientation | AA | both | Not assessed | Test portrait and landscape. |
| 1.3.5 Identify Input Purpose | AA | both | Manual review | Check personal-data autocomplete purpose tokens and context. |
| 1.4.1 Use of Color | A | both | Not assessed | Inspect rendered information/state cues. |
| 1.4.2 Audio Control | A | both | Manual review | `media-autoplay-audio-review`; verify audible autoplay duration and controls. |
| 1.4.3 Contrast (Minimum) | AA | both | Manual review | `contrast-review`; measure rendered text colors/states. |
| 1.4.4 Resize Text | AA | both | Manual review | `text-resize-review`; test 200% zoom. |
| 1.4.5 Images of Text | AA | both | Not assessed | Review rendered images of text and exceptions. |
| 1.4.10 Reflow | AA | both | Manual review | `text-resize-review`; test 320 CSS px / 400% zoom. |
| 1.4.11 Non-text Contrast | AA | both | Manual review | `contrast-review`; measure control/focus/object contrast. |
| 1.4.12 Text Spacing | AA | both | Not assessed | Apply WCAG spacing overrides. |
| 1.4.13 Hover or Focus Content | AA | both | Not assessed | Test dismissible, hoverable, persistent behavior. |
| 2.1.1 Keyboard | A | both | Manual review | `keyboard-operation-review`; operate all interactions by keyboard. |
| 2.1.2 No Keyboard Trap | A | both | Manual review | `keyboard-trap-review`; move focus into/out of components. |
| 2.1.4 Character Key Shortcuts | A | 2.1+ | Manual review | `character-key-shortcut-review`; verify disable/remap/focus-only. |
| 2.2.1 Timing Adjustable | A | both | Partial automatic | `meta-refresh-delay`; test each time limit. |
| 2.2.2 Pause, Stop, Hide | A | both | Not assessed | Test moving/blinking/updating content. |
| 2.3.1 Three Flashes | A | both | Not assessed | Analyze rendered animation/media. |
| 2.4.1 Bypass Blocks | A | both | Manual review | `bypass-blocks-review`; verify skip/landmark navigation. |
| 2.4.2 Page Titled | A | both | Partial automatic | `document-title-missing`; review descriptive uniqueness. |
| 2.4.3 Focus Order | A | both | Manual review | `focus-order-review`; tab through workflows. |
| 2.4.4 Link Purpose | A | both | Partial automatic | `link-name-missing`; review purpose in context. |
| 2.4.5 Multiple Ways | AA | both | Not assessed | Check a page set, not one document. |
| 2.4.6 Headings and Labels | AA | both | Partial automatic | Heading/name rules; review descriptive quality. |
| 2.4.7 Focus Visible | AA | both | Manual review | `focus-visible-review`; use keyboard in every state. |
| 2.4.11 Focus Not Obscured | AA | 2.2+ | Manual review | `focus-obscured-review`; inspect focus indicator geometry. |
| 2.5.1–2.5.4 Pointer/Gesture/Label/Motion | A | both | Manual review | Use the corresponding pointer, label-in-name, and motion review items. |
| 2.5.7 Dragging Movements | AA | 2.2+ | Manual review | `dragging-movement-review`; verify a non-drag alternative. |
| 2.5.8 Target Size | AA | 2.2+ | Manual review | `target-size-review`; measure CSS pixels and exceptions. |
| 3.1.1 Language of Page | A | both | Partial automatic | `html-lang-missing`, `html-lang-invalid`; review actual default language and page context. |
| 3.1.2 Language of Parts | AA | both | Partial automatic | `element-lang-invalid` plus `language-of-parts-review`; review actual human-language changes, inheritance, visibility, flat-tree scope, and exceptions. |
| 3.2.1 On Focus / 3.2.2 On Input | A | both | Manual review | Use context-change review items and run the interaction. |
| 3.2.3/3.2.4 Consistency | AA | both | Not assessed | Compare a page set, not a single input. |
| 3.2.6 Consistent Help | A | 2.2+ | Not assessed | Compare repeated help mechanisms across a flow. |
| 3.3.1 Error Identification | A | both | Manual review | `form-error-review`; submit invalid data. |
| 3.3.2 Labels or Instructions | A | both | Partial automatic | `form-control-name-missing`; review instructions/required state. |
| 3.3.3/3.3.4 Error Suggestion/Prevention | AA | both | Manual review | `form-error-review`; test correction and consequential submission. |
| 3.3.7 Redundant Entry | A | 2.2+ | Not assessed | Test a multi-step flow. |
| 3.3.8 Accessible Authentication | AA | 2.2+ | Manual review | `authentication-review`; test cognitive-function alternatives. |
| 4.1.1 Parsing | A | 2.1 only | Removed in 2.2 | Historical only; `duplicate-id` is not reported as 2.2 conformance. |
| 4.1.2 Name, Role, Value | A | both | Partial automatic | Names including ordered direct-target `aria-labelledby` sources and direct SVG `<title>` sources for native and selected custom roles, WAI-ARIA 1.2 attribute names, selected role fallback/states and documented role/property compatibility, custom slider/scrollbar numeric range consistency (including scrollbar controls/valuenow), selected required-context relationships, and ID relationships; review dynamic changes and unresolved SVG/browser name sources. |
| 4.1.3 Status Messages | AA | both | Manual review | `status-message-review`; trigger updates with assistive technology. |

The grouped rows retain every A/AA criterion; the public catalog contains one
record per criterion (56 including historical 4.1.1). CSS, runtime scripts,
shadow DOM, accessibility-tree behavior, media content and cross-page behavior
are intentionally not converted into asserted violations.

## Not WCAG conformance findings

`heading-level-skipped`, `multiple-main`, navigation landmark prompts,
`button-implicit-submit`, `viewport-zoom-disabled`, and the two label
association/content-model checks are structure or
resilience prompts. They can be useful engineering signals, but A11yTrace does
not label them as automatic WCAG failures.
