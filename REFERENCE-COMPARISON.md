# Reference comparison

A11yTrace is original MoonBit code. It uses `bobzhang/html_parser` for DOM
parsing, but does not copy the source code of any auditing tool.

## References and licenses

- [HTML-Validate](https://html-validate.org/) and its
  [rule reference](https://html-validate.org/rules/) inform the separation of
  document-wide and fragment-safe checks. HTML-Validate is
  [MIT licensed](https://github.com/html-validate/html-validate/blob/master/LICENSE).
- [W3C ACT Rules](https://www.w3.org/WAI/standards-guidelines/act/rules/) are
  used to bound individual accessibility-rule claims.
- [axe-core](https://github.com/dequelabs/axe-core) is a useful broader
  accessibility-engine reference and is
  [MPL-2.0 licensed](https://github.com/dequelabs/axe-core/blob/develop/LICENSE).
  It is not a dependency and its source is not copied.

## Current comparison

| Capability | A11yTrace status | Notes |
| --- | --- | --- |
| Document versus fragment input | Supported | `audit_html` recognizes a full-document marker and applies document-only rules; `audit_html_fragment` is always local to the supplied markup. |
| Stable rule selection and JSON findings | Supported | A small fixed rule set, stable IDs, source positions when the parser supplies them, and parse diagnostics are available. |
| HTML-Validate's broad HTML syntax, content-model, metadata, and framework support | Not supported | A11yTrace is not an HTML conformance validator. |
| Accessible names for native controls, links, buttons, headings, and iframes | Partially supported | It checks selected static sources only; it does not implement the full browser Accessible Name algorithm. |
| ID and label/IDREF resolution | Partially supported | IDs and `label[for]` are indexed once per audited input. Ambiguous duplicate IDs, empty values, missing targets, fragment-external targets, and cyclic ARIA references do not prove a name. |
| CSS visibility, layout, focusability, and rendered accessibility tree | Not supported automatically | Static HTML cannot determine stylesheet cascades, computed visibility, focus order, shadow DOM, or browser/assistive-technology behavior. These require manual review or browser-based tooling. |
| Script-created or runtime-mutated DOM state | Not supported automatically | The library audits only the supplied static markup. |

The comparison is deliberately not a coverage claim for HTML-Validate,
axe-core, WCAG, or ACT. A finding is a focused static signal; absence of a
finding means only that the implemented checks did not detect an issue.
