# Limited ARIA role/attribute compatibility table

`aria-role-attribute-incompatible` is a deliberately bounded static check. It
uses the [WAI-ARIA 1.2 role model](https://www.w3.org/TR/wai-aria-1.2/#role_definitions)
and [state and property definitions](https://www.w3.org/TR/wai-aria-1.2/#state_prop_values),
but it is not a complete ARIA validator. A11yTrace is original MoonBit code;
it does not copy axe-core or any other validator.

The rule first applies the library's ordered concrete-role fallback. For
example, `role="future-role searchbox"` uses `searchbox`; an unknown-only role
is outside this rule. It then inspects only the attribute rows below. The
implementation has no browser accessibility tree, CSS, custom-element
semantics, or host-language conformance engine.

## Checked role/property rows

| Effective explicit role | Supported selected attributes | Inheritance or prohibition modeled |
| --- | --- | --- |
| `button` | none of this table's non-global attributes | explicit role row; unsupported selected properties are reported |
| `combobox` | `aria-autocomplete` | direct WAI-ARIA 1.2 support |
| `textbox` | `aria-autocomplete`, `aria-placeholder` | direct support |
| `searchbox` | `aria-autocomplete`, `aria-placeholder` | inherits textbox support |
| `grid`, `listbox`, `tablist`, `tree` | `aria-multiselectable` | direct support |
| `treegrid` | `aria-multiselectable` | inherits grid support |
| `option`, `tab` | `aria-selected` | direct support |
| `emphasis` | neither `aria-label` nor `aria-labelledby` | WAI-ARIA 1.2 explicitly prohibits naming this role |

For the table's other modeled roles, a present selected attribute that is not
listed as supported produces a confirmed `Finding`. Thus a custom
`role="button" aria-autocomplete="list"` is reported. The rule checks each
present selected attribute in stable table order, so two separately forbidden
name properties on one `emphasis` element yield two specific findings.

`aria-label` and `aria-labelledby` are otherwise treated as name-capable in
this limited table. The rule does **not** validate whether a supplied name is
useful or calculate a browser accessible name.

The WAI-ARIA 1.2 global properties are treated as role-compatible in this
batch: `aria-atomic`, `aria-braillelabel`, `aria-brailleroledescription`,
`aria-busy`, `aria-controls`, `aria-current`, `aria-describedby`,
`aria-description`, `aria-details`, `aria-disabled`, `aria-dropeffect`,
`aria-errormessage`, `aria-flowto`, `aria-grabbed`, `aria-haspopup`,
`aria-hidden`, `aria-invalid`, `aria-keyshortcuts`, `aria-label`,
`aria-labelledby`, `aria-live`, `aria-owns`, `aria-relevant`, and
`aria-roledescription`. The two naming properties have the `emphasis`
prohibition shown above. This compatibility rule does not validate their
values, their separate relationship targets, or deprecated-property advice.

## Explicit exclusions and ownership

- `aria-checked` remains owned by `aria-checked-role-incompatible`; this rule
  never emits a second compatibility finding for it.
- `aria-state-value-invalid`, `aria-required-property-missing`, and
  `aria-range-value-invalid` retain their selected token, required-property,
  and numeric-range responsibilities. This rule does not claim their
  attributes.
- The rule leaves global attributes such as `aria-describedby`, `aria-controls`,
  `aria-disabled`, `aria-hidden`, `aria-live`, and `aria-roledescription` to
  their dedicated checks or to browser review; it does not reject them merely
  because this small table has no row for them.
- Native `button`, `input`, `select`, and `textarea` elements are excluded,
  including when an explicit role is present. Their HTML and ARIA-in-HTML
  constraints are host-language-specific and remain outside this rule.
- Elements without a known explicit concrete role, abstract-only roles, and
  concrete roles outside the table are skipped rather than guessed about.
  `aria-attribute-undefined` still owns unknown `aria-*` names.

[ARIA in HTML](https://www.w3.org/TR/html-aria/) imposes additional
host-language rules, including cases where author naming is prohibited on an
HTML element. This limited explicit-role table does not implement those
element-specific restrictions; native host elements are intentionally excluded
instead of being classified from incomplete static information.

## Roles not covered by this property table

The remaining WAI-ARIA 1.2 concrete roles are not a claim of permissiveness or
invalidity here: `alert`, `alertdialog`, `application`, `article`, `banner`,
`blockquote`, `caption`, `cell`, `checkbox`, `code`,
`columnheader`, `complementary`, `contentinfo`, `definition`, `deletion`,
`dialog`, `directory`, `document`, `feed`, `figure`, `form`, `generic`,
`gridcell`, `group`, `heading`, `img`, `insertion`, `link`, `list`, `listitem`,
`log`, `main`, `marquee`, `math`, `menu`, `menubar`, `menuitem`,
`menuitemcheckbox`, `menuitemradio`, `meter`, `navigation`, `none`, `note`,
`paragraph`, `presentation`, `progressbar`, `radio`, `radiogroup`, `region`,
`row`, `rowgroup`, `rowheader`, `scrollbar`, `search`, `separator`, `slider`,
`spinbutton`, `status`, `strong`, `subscript`, `suggestion`, `superscript`,
`switch`, `table`, `tabpanel`, `term`, `time`, `timer`, `toolbar`, `tooltip`,
and `treeitem`. A role can appear in a checked row above and still have many
other properties that this batch does not model.

## Test evidence and axe-core comparison

`examples/comparison/aria-role-attribute-compatibility.html` is authored for
this repository. Its focused cases are covered by the named tests
`role attribute compatibility uses its small inherited and global-property
table` and `role attribute compatibility keeps specialized checked and JSON
findings distinct`.

For development comparison, axe-core's `aria-allowed-attr` and
`aria-prohibited-attr` rules are broader references. A11yTrace intentionally
differs by checking only this table, by retaining the older dedicated
`aria-checked-role-incompatible` rule as the sole owner of `aria-checked`, and
by skipping native form controls rather than attempting ARIA-in-HTML's full
element-specific mapping. The fixture is suitable for a local axe comparison,
but axe-core is not a build, package, or runtime dependency.
