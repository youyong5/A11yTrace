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
| Accessible names for native controls, links, buttons, headings, iframes, and linked areas | Partially supported | It checks selected static sources, including direct SVG `<title>`, only; it does not implement the full browser Accessible Name algorithm. |
| Image text alternatives | Partially supported | A dedicated `<img>` check distinguishes selected static names, explicit decoration/exclusion, static missing alternatives, and unmodeled-role review. It does not judge image purpose or alternative quality. |
| ID and label/IDREF resolution | Partially supported | IDs and `label[for]` are indexed once per audited input. `label[for]`, `aria-labelledby`, and `aria-describedby` can report a missing or ambiguous target; a uniquely resolved `label[for]` target is also checked when it is a known non-labelable built-in, and each label can report multiple known labelable built-in descendants. Unique `aria-labelledby` targets are read in order from their direct `aria-label`/text-image-alt/SVG-title/title sources; the target's own `aria-labelledby` is not followed. Custom-element form association, CSS visibility, and full browser AccName traversal remain outside scope. |
| Table `headers` and explicit `scope` | Partially supported | A `td` or `th` token must target another unique cell in the same nearest table; explicit `th[scope]` is limited to HTML's four keywords. Role, visibility, semantic header quality, and implicit association are outside this static check. |
| CSS visibility, layout, focusability, and rendered accessibility tree | Not supported automatically | Static HTML cannot determine stylesheet cascades, computed visibility, focus order, shadow DOM, or browser/assistive-technology behavior. These require manual review or browser-based tooling. |
| `aria-hidden` and focus conflicts | Partially supported | Potentially focusable descendants are emitted as review items; A11yTrace does not assert a rendered focus conflict without CSS and runtime information. |
| Native landmark structure and names | Partially supported | It checks multiple `main` elements and distinguishes multiple native navigation landmarks using selected static naming sources only. |
| ARIA role and attribute vocabulary | Partially supported | It detects the complete ARIA 1.2 abstract-role set, undefined `aria-*` names, and ordered concrete WAI-ARIA 1.2 fallback. A separate documented table checks only selected explicit role/property pairs and inheritance; it is not complete role-permission, extension-vocabulary, ARIA-in-HTML, or browser-mapping validation. |
| Selected ARIA state and range value tokens | Partially supported | A11yTrace validates only a documented small set of boolean, tristate, token-valued attributes, and exact custom slider/scrollbar numeric range relationships; ACT 6a7281 is broader. |
| Timed meta refresh | Partially supported | Complete documents with a supported numeric non-zero delay are reported; loop detection and HTML-Validate's long-delay option are not implemented. |
| Script-created or runtime-mutated DOM state | Not supported automatically | The library audits only the supplied static markup. |
| WCAG 2.1/2.2 A/AA coverage index | Supported as a capability directory | `wcag_aa_criteria()` records per-criterion version presence, narrow automatic mappings, review steps, and the 2.2 removal of 4.1.1; it is not a conformance engine. |
| ARIA widget roles and required properties | Partially supported | Narrow checks cover custom button/link/radio/textbox/searchbox and selected named widget roles, five required-property patterns including scrollbar controls/valuenow, exact custom slider/scrollbar range comparisons, and selected IDREF attributes; A11yTrace does not claim complete role/attribute validation or browser fallback processing. |
| Page and content language tags | Partially supported | A fixed generated IANA primary-language set checks non-empty root `lang` in complete documents and non-empty explicit body/fragment `lang`. It intentionally accepts known primaries with loose later subtags, and cannot reproduce ACT's browser flat tree, inherited-text, visibility, or actual-language applicability. |
| Media, keyboard, focus, target size and authentication | Manual-review markers | Located review items identify relevant markup but deliberately require browser/runtime verification. |

The comparison is deliberately not a coverage claim for HTML-Validate,
axe-core, WCAG, or ACT. A finding is a focused static signal; absence of a
finding means only that the implemented checks did not detect an issue.

## Reproducible development comparison

The fixtures in `examples/comparison/` are authored for this repository. They
are not copied from HTML-Validate and HTML-Validate is not a MoonBit dependency
or a runtime dependency of A11yTrace. With Node.js and `npx`, this independent
development-only comparison was run on 2026-09-24 with HTML-Validate 11.16.0:

```text
npx --yes html-validate@11.16.0 --rule meta-refresh:2 examples/comparison/meta-refresh-delay.html
npx --yes html-validate@11.16.0 --rule no-dup-id:2 examples/comparison/duplicate-id.html
```

| Fixture | Shared semantic result | Intentional difference |
| --- | --- | --- |
| `meta-refresh-delay.html` | A11yTrace `meta-refresh-delay` and HTML-Validate `meta-refresh` both report the five-second refresh. | HTML-Validate also diagnoses instant refresh loops and offers a long-delay option; A11yTrace does neither. |
| `duplicate-id.html` | A11yTrace `duplicate-id` and HTML-Validate `no-dup-id` both report the second `duplicate` ID. | A11yTrace attaches its stable element path and uses the same index to make ARIA references ambiguous; it does not validate ID syntax. |
| `aria-role-attribute-compatibility.html` | The self-authored custom `role=button`/`aria-autocomplete` and `role=emphasis` naming cases are suitable for comparison with axe-core `aria-allowed-attr` and `aria-prohibited-attr`. | axe-core is broader. A11yTrace checks only its published role/property rows, leaves `aria-checked` to its dedicated compatibility rule, and skips native form controls rather than attempting the full ARIA-in-HTML mapping. |
| `aria-required-context-role.html` | The self-authored valid tablist/tab and invalid nested tab cases are suitable for comparison with axe-core `aria-required-parent`. | axe-core is broader. A11yTrace implements only its published WAI-ARIA 1.2 table, accepts one unique local `aria-owns` owner, and deliberately skips root/hidden/presentational/ambiguous ownership instead of reconstructing a browser accessibility tree. |
| `static-accessible-name.html` | The direct SVG `<title>` link and button have a static name; the SVG `<desc>`-only controls and a button whose IDREF target only points at another IDREF have no confirmed static name. | The fixture is compared with axe-core `link-name` and `button-name`; A11yTrace keeps browser-only SVG mappings as review items instead of treating them as definite names. |
| `image-text-alternative.html` | Non-empty alt/ARIA/title sources and static decorative cases are accepted; bare or explicit image-role empty alternatives are reported. | The fixture is compared with axe-core `image-alt`; A11yTrace intentionally does not evaluate whether text serves the image purpose and leaves unmodeled role mappings as review. |

To run that development-only comparison with a ChromeDriver compatible with the
locally installed Chrome:

```text
npx --yes @axe-core/cli@4.11.0 --rules aria-allowed-attr,aria-prohibited-attr examples/comparison/aria-role-attribute-compatibility.html
npx --yes @axe-core/cli@4.11.0 --rules aria-required-parent file:///absolute/path/to/A11yTrace/examples/comparison/aria-required-context-role.html
npx --yes @axe-core/cli@4.11.0 --rules link-name,button-name file:///absolute/path/to/A11yTrace/examples/comparison/static-accessible-name.html
npx --yes @axe-core/cli@4.11.0 --rules image-alt file:///absolute/path/to/A11yTrace/examples/comparison/image-text-alternative.html
```

The role/property command was attempted on this checkout on 2026-09-30, but
axe-core 4.11.4 selected ChromeDriver 154 while the installed Chrome was
153.0.8010.53, so no result is claimed for that fixture. The required-context
command was run on the same date with the explicit local `file:///` URL: axe
reported exactly the two intended invalid tab/option cases under
`aria-required-parent`. Running A11yTrace with only
`aria-required-context-role` reports those same two elements. The test does
not establish general equivalence, and axe-core remains a development-only
tool rather than a build, package, or runtime dependency.

The static-name command was run on this checkout on 2026-09-30. axe-core
reported the SVG `<desc>`-only link and button, plus the button whose direct
IDREF target only points at another IDREF, under `link-name` and `button-name`.
It did not report the corresponding direct SVG `<title>` fixtures. A11yTrace
agrees for the direct-title and indirect-IDREF cases; it emits ReviewItems,
rather than definite findings, for the desc-only cases because it intentionally
does not claim that `<desc>` supplies a browser accessible name.

The image-text-alternative command was run on this checkout on 2026-09-30.
axe-core 4.11.4 reported the self-authored whitespace-only `alt`, omitted
`alt`, and focusable `role="none"` images under `image-alt`. A11yTrace reports
those same three cases through `img-text-alternative-missing` when that rule is
selected. It additionally reports the fixture's empty-name `role="img"` and
stateful presentational-role cases, following the relevant static ACT examples;
axe did not report those with `image-alt` in this run. A11yTrace still leaves unmodeled
explicit roles as ReviewItems and does not assess image purpose or alternative
quality. This is a scoped comparison, not a claim of tool equivalence.

This small comparison demonstrates selected aligned semantics only. It is not a
claim of equivalent configuration, parser behavior, rule coverage, or output
format. A custom-rule extension was deliberately not added in this batch:
exposing the parser DOM or mutable audit context would not yet give external
MoonBit packages a stable, read-only context contract across targets. The rule
metadata directory and explicit ID selection are kept stable first; a future
extension would need a separately versioned public context and cross-package
execution tests.
