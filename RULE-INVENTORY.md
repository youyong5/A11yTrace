# Built-in rule inventory

This is the current release-review inventory. It deliberately distinguishes
directory metadata from execution:
there are **81 selectable metadata IDs**, comprising **50 confirmed-finding
checks**, **7 static-hint checks**, and **24 manual-review triggers**. The
first two kinds append `Finding` values; review triggers append `ReviewItem`
values. A review-only detailed JSON result has `assessment: "needs_review"`;
none of these counts is a count of WCAG criteria automatically passed.

Source-key locations are in `a11ytrace.mbt`: **C** = common traversal
`1965–2140`; **EA** = extended ARIA `2142–2235`; **ES** = extended structure
`2237–2294`; **ER** = extended review triggers `2296–2465`; **H** = helpers
`2503–2640`; **O** = original helpers `2712–3678`. Tests are named exactly as
they appear in `a11ytrace_test.mbt`; a test may cover more than one row.

| ID | Origin | Result | Actual trigger | WCAG mapping / practice | Source | Test evidence |
| --- | --- | --- | --- | --- | --- | --- |
| img-alt-missing | original | confirmed | `img` omits `alt` | 1.1.1 | C/O | reports an image without alt; accepts an explicitly decorative image |
| img-text-alternative-missing | new | confirmed/review | `img` has no supported static name and is not statically decorative; unmodeled explicit roles review | 1.1.1 | C/H | image text alternatives distinguish names decoration and missing alternatives; image semantic rule keeps unmodeled role mappings as review |
| form-control-name-missing | original | confirmed/review | selected input/select/textarea has no supported static name | 3.3.2, 4.1.2 | C/O | reports placeholder-only and empty or invalid label references; accepts direct SVG title, leaves unresolved SVG as review |
| link-name-missing | original | confirmed/review | `a[href]` has no supported static name | 2.4.4, 4.1.2 | C/O | reports empty links and decorative-image-only links; accepts direct SVG title, leaves unresolved SVG as review |
| button-name-missing | original | confirmed/review | native button/input button/image has no static name | 4.1.2 | C/O | reports empty and decorative-image-only native buttons; accepts direct SVG title, leaves unresolved SVG as review |
| heading-level-skipped | original | static hint | later native heading drops two+ levels | 2.4.6 review practice | C/O | only reports downward native heading level skips |
| heading-name-missing | original | confirmed/review | native heading lacks supported name | 2.4.6 | C/O | reports empty headings, accepts direct SVG title, and ignores template headings |
| document-title-missing | original | confirmed | complete document has no non-empty title | 2.4.2 | C/O | reports missing document title and language only for complete documents |
| html-lang-missing | original | confirmed | complete-document `html` has no non-empty `lang` | 3.1.1 | C/O | reports missing document title and language only for complete documents; empty values do not duplicate invalid-tag findings |
| iframe-name-missing | original | confirmed/review | iframe has no title/ARIA static name | 4.1.2 | C/O | recognizes supported direct-target IDREF names including direct SVG title; unresolved sources are review |
| duplicate-id | original | confirmed | later non-empty duplicate ID in input scope | 4.1.1 historical / relationship practice | C/O | indexes duplicate IDs once and keeps ambiguous references unnamed |
| reference-target-invalid | original | confirmed | label-for/labelledby/describedby has missing/ambiguous ID | 1.3.1, 4.1.2 | C/O | reports invalid label and ARIA references without claiming names are missing |
| label-for-target-not-labelable | new | confirmed | `label[for]` uniquely resolves to a known non-labelable built-in element | HTML label association/content-model practice; not a WCAG verdict | C/O | label for reports only unique known built-in targets that are not labelable; keeps missing duplicate and custom targets conservative |
| label-multiple-labelable-descendants | new | confirmed | a label contains two or more known built-in labelable descendants | HTML label content-model practice; not a WCAG verdict | C/O | label reports multiple known labelable descendants only once; accepts one control and skips custom or template content |
| table-headers-invalid | original | confirmed | `headers` target is not another unique cell in same table | 1.3.1 | C/O | checks each table headers token against other cells in the same table |
| area-alt-missing | original | confirmed | `area[href]` has no non-empty `alt` | 1.1.1, 2.4.4 | C/O | reports clickable image map areas without non-empty alt text |
| aria-hidden-focus-review | original | manual review | potentially focusable item in `aria-hidden=true` subtree | 4.1.2 review | C/O | aria hidden ancestors cannot be undone and disabled differs from aria disabled |
| body-aria-hidden | original | confirmed | complete-document body is `aria-hidden=true` | 4.1.2 | C/O | body aria hidden and multiple main are document-only findings |
| multiple-main | original | static hint | complete document has more than one native main | landmark practice | C/O | body aria hidden and multiple main are document-only findings |
| navigation-landmark-name-missing | original | static hint/review | repeated native nav has no static distinguishing name | landmark practice | C/O | multiple navigation landmarks need distinct static names; bounded SVG uncertainty is review |
| navigation-landmark-name-duplicate | original | static hint | later repeated native nav name duplicates earlier name | landmark practice | C/O | multiple navigation landmarks need distinct static names, including ordered IDREF names |
| aria-abstract-role | original | confirmed | no concrete fallback is present and `role` contains an ARIA 1.2 abstract token | 4.1.2 | C/O | abstract role rule covers the complete ARIA 1.2 abstract role set; concrete role fallback suppresses abstract tokens |
| meta-refresh-delay | original | confirmed | complete-document refresh has supported nonzero numeric delay | 2.2.1 | C/O | reports supported nonzero meta refresh delays in complete documents only |
| aria-state-value-invalid | original | confirmed | selected documented ARIA state token is invalid | 4.1.2 | C/O | checks only documented ARIA state token types |
| button-implicit-submit | original | static hint | form button lacks/has empty type | best practice | C/O | suggests explicit button types only for missing or empty form buttons |
| aria-attribute-undefined | new | confirmed | an `aria-*` attribute name is absent from the WAI-ARIA 1.2 attribute set | 4.1.2 | C/H | accepts WAI-ARIA 1.2 attribute names and reports unsupported aria attributes |
| role-value-invalid | new | confirmed | non-empty `role` token list has neither a concrete WAI-ARIA 1.2 fallback nor an abstract-role finding | 4.1.2 | C/H | uses ordered concrete role fallback without duplicate abstract or invalid role reports |
| table-scope-invalid | new | confirmed | `th` has an explicit `scope` other than `row`, `col`, `rowgroup`, or `colgroup` | HTML table conformance practice; not a WCAG verdict | C/H | checks only explicit invalid table header scope values |
| role-button-name-missing | new | confirmed/review | effective custom `role=button` lacks a supported static name; unresolved SVG source becomes review | 4.1.2 | EA/H | custom button and link roles accept direct SVG title and shared static sources |
| role-link-name-missing | new | confirmed/review | effective custom `role=link` lacks a supported static name; unresolved SVG source becomes review | 4.1.2 | EA/H | custom button and link roles accept direct SVG title and shared static sources |
| role-radio-name-missing | new | confirmed/review | effective custom `role=radio` lacks a supported static name; unresolved SVG source becomes review | 4.1.2 | EA/H | custom radio roles accept direct SVG title and report empty effective roles |
| role-textbox-name-missing | new | confirmed/review | effective custom `role=textbox` lacks author-provided `aria-labelledby`, `aria-label`, or title; unresolved SVG IDREF becomes review | 4.1.2 | EA/H | custom text input roles accept direct SVG title but distinguish author names from editable content and placeholders |
| role-searchbox-name-missing | new | confirmed/review | effective custom `role=searchbox` lacks author-provided `aria-labelledby`, `aria-label`, or title; unresolved SVG IDREF becomes review | 4.1.2 | EA/H | custom text input roles accept direct SVG title but distinguish author names from editable content and placeholders |
| aria-required-property-missing | new | confirmed | custom checkbox/switch/radio lacks checked, combobox expanded, slider valuenow, or scrollbar controls/valuenow | 4.1.2 | EA/H | scrollbar required properties distinguish missing values and invalid IDREFs |
| aria-range-value-invalid | new | confirmed/review | custom effective slider/scrollbar has malformed explicit numeric min/max/now, reversed bounds, or current value outside the explicit/default 0–100 range | 4.1.2 | EA/H | range values accept exact decimals, scientific notation, and default bounds; report malformed values and inconsistent bounds once per element; preserve diagnostics and review unbounded exponents without guessing |
| aria-idref-invalid | new | confirmed | selected ARIA local IDREF missing/ambiguous | 4.1.2 | EA/H | extended references and viewport check handle valid tokens and document scope |
| aria-required-context-role | new | confirmed | selected explicit ARIA role has no modeled required-context ancestor or one unique valid local `aria-owns` owner | 4.1.2 partial static evidence | EA/H | required ARIA context accepts modeled DOM and native implicit relationships; required ARIA context leaves ambiguous ownership to IDREF validation |
| role-checkbox-name-missing | new | confirmed/review | checkbox role lacks name; SVG source becomes review | 4.1.2 | EA/H | ARIA role-name rules cover author names and conservative role image handling |
| role-combobox-name-missing | new | confirmed/review | combobox role lacks name; SVG source becomes review | 4.1.2 | EA/H | ARIA role-name rules cover author names and conservative role image handling |
| role-slider-name-missing | new | confirmed/review | slider role lacks name; SVG source becomes review | 4.1.2 | EA/H | ARIA role-name rules cover author names and conservative role image handling |
| role-progressbar-name-missing | new | confirmed/review | progressbar role lacks name; SVG source becomes review | 4.1.2 | EA/H | ARIA role-name rules cover author names and conservative role image handling |
| role-meter-name-missing | new | confirmed/review | meter role lacks name; SVG source becomes review | 4.1.2 | EA/H | ARIA role-name rules cover author names and conservative role image handling |
| role-img-name-missing | new | confirmed/review | image role has no author name; plain descendant text is not accepted | 1.1.1, 4.1.2 | EA/H | ARIA role-name rules cover author names and conservative role image handling |
| role-dialog-name-missing | new | confirmed/review | dialog/alertdialog lacks name; SVG source becomes review | 4.1.2 | EA/H | ARIA role-name rules cover author names and conservative role image handling |
| role-heading-level-missing | new | confirmed | ARIA heading omits 1–6 `aria-level` | 1.3.1 | EA/H | selected ARIA required-state rules distinguish missing and valid values |
| role-tab-selected-missing | new | confirmed | tab omits `aria-selected` | 4.1.2 | EA | selected ARIA required-state rules distinguish missing and valid values |
| role-switch-checked-missing | new | confirmed | switch omits `aria-checked` | 4.1.2 | EA/H | selected ARIA required-state rules distinguish missing and valid values |
| nested-interactive | new | confirmed | focusable/selected role inside link or button | 4.1.2 / HTML practice | ES/H | checks structural rules without treating inert template contents as input |
| list-structure-invalid | new | confirmed | direct `ul`/`ol` child is not li/script/template | 1.3.1 / HTML practice | ES/H | checks structural rules without treating inert template contents as input |
| definition-list-structure-invalid | new | confirmed | direct `dl` child is not dt/dd/div/script/template | 1.3.1 / HTML practice | ES/H | checks structural rules without treating inert template contents as input |
| table-header-name-missing | new | confirmed | `th` lacks supported static name; SVG is conservative | 1.3.1 | ES/H | checks structural rules without treating inert template contents as input |
| viewport-zoom-disabled | new | static hint | complete-document viewport has user scalable disabled or max scale <2 | resize/reflow practice | ES/H | extended references and viewport check handle valid tokens and document scope |
| media-alternative-review | new | manual review | audio/video element | 1.2.1–1.2.5 | ER | detailed review rules locate static risk markers without claiming findings |
| media-autoplay-audio-review | new | manual review | audio/video has autoplay | 1.4.2 | ER | detailed review rules locate static risk markers without claiming findings |
| keyboard-operation-review | new | manual review | selected custom interactive role | 2.1.1 | ER/H | detailed review rules locate static risk markers without claiming findings |
| keyboard-trap-review | new | manual review | dialog/alertdialog role | 2.1.2 | ER | remaining review markers have specific triggers and clean markup has none |
| character-key-shortcut-review | new | manual review | `accesskey` exists | 2.1.4 | ER | detailed review rules locate static risk markers without claiming findings |
| focus-order-review | new | manual review | potentially focusable element has explicit tabindex | 2.4.3 | ER | detailed review rules locate static risk markers without claiming findings |
| focus-visible-review | new | manual review | potentially focusable element has explicit tabindex | 2.4.7 | ER | detailed review rules locate static risk markers without claiming findings |
| focus-obscured-review | new | manual review | potentially focusable element has explicit tabindex | 2.4.11 | ER | detailed review rules locate static risk markers without claiming findings |
| target-size-review | new | manual review | potentially focusable element has explicit tabindex | 2.5.8 | ER | detailed review rules locate static risk markers without claiming findings |
| dragging-movement-review | new | manual review | `draggable` exists | 2.5.7 | ER | detailed review rules locate static risk markers without claiming findings |
| pointer-cancellation-review | new | manual review | `onmousedown` or `onpointerdown` exists | 2.5.2 | ER | detailed review rules locate static risk markers without claiming findings |
| motion-actuation-review | new | manual review | device-motion/orientation event attribute exists | 2.5.4 | ER | detailed review rules locate static risk markers without claiming findings |
| label-in-name-review | new | manual review | non-empty aria-label and visible text | 2.5.3 | ER | remaining review markers have specific triggers and clean markup has none |
| language-of-parts-review | new | manual review | non-empty `lang` in supplied fragment or complete-document body subtree | 3.1.2 | ER | known-tag markup still needs actual language, inheritance, and exception review |
| on-focus-context-review | new | manual review | `onfocus` exists | 3.2.1 | ER | remaining review markers have specific triggers and clean markup has none |
| on-input-context-review | new | manual review | selected form control has `onchange` | 3.2.2 | ER | detailed review rules locate static risk markers without claiming findings |
| form-error-review | new | manual review | form element | 3.3.1/3.3.3/3.3.4 | ER | detailed review rules locate static risk markers without claiming findings |
| authentication-review | new | manual review | password input | 3.3.8 | ER/H | detailed review rules locate static risk markers without claiming findings |
| status-message-review | new | manual review | status/alert role or aria-live exists | 4.1.3 | ER | remaining review markers have specific triggers and clean markup has none |
| bypass-blocks-review | new | manual review | complete-document html element | 2.4.1 | ER | remaining review markers have specific triggers and clean markup has none |
| meaningful-sequence-review | new | manual review | selected text/control element | 1.3.2 | ER | remaining review markers have specific triggers and clean markup has none |
| contrast-review | new | manual review | selected text/control element | 1.4.3/1.4.11 | ER | remaining review markers have specific triggers and clean markup has none |
| text-resize-review | new | manual review | complete-document html element | 1.4.4/1.4.10 | ER | remaining review markers have specific triggers and clean markup has none |
| aria-checked-role-incompatible | next version | confirmed | explicit effective role that does not support `aria-checked` carries that attribute | 4.1.2 static semantic-markup evidence | ES/H | accepts every supported checked role, radio fallback, and native controls; default selection avoids a duplicate malformed-value Finding |
| listitem-orphan | next version | confirmed | recovered `li` direct parent is not ul/ol/menu | HTML list content-model practice; not a per-instance WCAG verdict | ES/H | reports a root orphan and accepts menu child; template contents are skipped |
| fieldset-legend-missing | next version | static hint | fieldset with multiple known native labelable descendants has no named first legend | form grouping best practice | ES/H | accepts a named first legend and one-control fieldset; reports empty/missing first legend |
| aria-role-attribute-incompatible | next version | confirmed | selected defined ARIA property is unsupported by a modeled effective explicit WAI-ARIA 1.2 role | 4.1.2 static semantic-markup evidence | EA/H | role attribute compatibility uses its small inherited and global-property table; JSON keeps dedicated checked findings distinct |
| html-lang-invalid | next version | confirmed | complete-document non-empty `html[lang]` has unknown primary language subtag or obvious separator/character failure | 3.1.1 static ACT evidence | C/H | language-tag checks accept ACT known-primary examples without strict later-subtag parsing |
| element-lang-invalid | next version | confirmed | non-empty explicit `lang` in fragment or complete-document body subtree has unknown primary language subtag or obvious separator/character failure | 3.1.2 partial static ACT evidence | C/H | element language tags respect document-body and fragment scope; JSON preserves diagnostics/order |

The role-name rows are catalogued as confirmed-finding rules because a definite
missing author/static name produces a `Finding`; an unresolved SVG/browser-name
branch produces a conservative `ReviewItem` under the same ID. This is an intentional
per-input outcome distinction, not an additional metadata ID.

`aria-range-value-invalid` is likewise catalogued as a confirmed-finding rule:
malformed explicit numeric tokens and provably inconsistent bounds produce a
`Finding`. An exponent with more than six digits cannot be safely expanded by
the exact static comparator, so that one bounded branch produces a `ReviewItem`
instead of guessing a comparison result.
