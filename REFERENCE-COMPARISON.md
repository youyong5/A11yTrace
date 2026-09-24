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
| Detailed static result categories | Supported | Detailed APIs keep definite findings and parser diagnostics separate from explicit browser/CSS review items. |
| HTML-Validate's broad HTML syntax, content-model, metadata, and framework support | Not supported | A11yTrace is not an HTML conformance validator. |
| Accessible names for native controls, links, buttons, headings, iframes, and linked areas | Partially supported | It checks selected static sources only; it does not implement the full browser Accessible Name algorithm. |
| ID and label/IDREF resolution | Partially supported | IDs and `label[for]` are indexed once per audited input. `label[for]`, `aria-labelledby`, and `aria-describedby` can report a missing or ambiguous target; only uniquely resolved text-bearing `aria-labelledby` targets establish a static name. |
| Table `headers` relationships | Partially supported | A `td` or `th` token must target another unique cell in the same nearest table. Role, visibility, and semantic header quality are outside this static check. |
| CSS visibility, layout, focusability, and rendered accessibility tree | Not supported automatically | Static HTML cannot determine stylesheet cascades, computed visibility, focus order, shadow DOM, or browser/assistive-technology behavior. These require manual review or browser-based tooling. |
| `aria-hidden` and focus conflicts | Partially supported | Potentially focusable descendants are emitted as review items; A11yTrace does not assert a rendered focus conflict without CSS and runtime information. |
| Native landmark structure and names | Partially supported | It checks multiple `main` elements and distinguishes multiple native navigation landmarks using selected static naming sources only. |
| ARIA role validity | Partially supported | It detects the complete ARIA 1.2 abstract-role set; it intentionally does not claim to validate all concrete roles or fallback behavior. |
| Script-created or runtime-mutated DOM state | Not supported automatically | The library audits only the supplied static markup. |

The comparison is deliberately not a coverage claim for HTML-Validate,
axe-core, WCAG, or ACT. A finding is a focused static signal; absence of a
finding means only that the implemented checks did not detect an issue.
