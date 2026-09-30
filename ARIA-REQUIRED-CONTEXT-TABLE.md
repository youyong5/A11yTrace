# Limited ARIA required-context table

`aria-required-context-role` is a deliberately narrow static relationship
check. It is based on WAI-ARIA 1.2's [Required Context
Role](https://www.w3.org/TR/wai-aria-1.2/#required-context-role) definition:
a role may be contained in, or owned by, a listed role. A11yTrace implements
its own MoonBit traversal and does not copy axe-core or another validator.

## Modeled role/context pairs

The following table is the complete scope of this rule in this release. The
role in the first column must be an effective, valid explicit WAI-ARIA 1.2
role; ordered fallback is honored, so `role="future-role tab"` is a `tab`.

| Child role | Allowed required context roles | WAI-ARIA 1.2 role reference |
| --- | --- | --- |
| `tab` | `tablist` | [tab](https://www.w3.org/TR/wai-aria-1.2/#tab) |
| `option` | `group`, `listbox` | [option](https://www.w3.org/TR/wai-aria-1.2/#option) |
| `cell`, `gridcell`, `columnheader`, `rowheader` | `row` | [cell](https://www.w3.org/TR/wai-aria-1.2/#cell), [gridcell](https://www.w3.org/TR/wai-aria-1.2/#gridcell) |
| `row` | `grid`, `rowgroup`, `table`, `treegrid` | [row](https://www.w3.org/TR/wai-aria-1.2/#row) |
| `listitem` | `directory`, `list` | [listitem](https://www.w3.org/TR/wai-aria-1.2/#listitem) |
| `menuitem`, `menuitemcheckbox`, `menuitemradio` | `group`, `menu`, `menubar` | [menuitem](https://www.w3.org/TR/wai-aria-1.2/#menuitem) |
| `treeitem` | `group`, `tree` | [treeitem](https://www.w3.org/TR/wai-aria-1.2/#treeitem) |

In addition, the parent-side model recognizes only the reliable native HTML
implicit roles needed by these rows: `ul`/`ol` as `list`, `table` as `table`,
`thead`/`tbody`/`tfoot` as `rowgroup`, and `tr` as `row`. Native child roles
are not independently audited by this rule, preventing overlap with the HTML
list and table checks. Roles such as `radio` are intentionally not selected:
they do not appear in this rule merely because they are common widgets.

## Static evidence and exclusions

A Finding requires an element parent in the recovered DOM, no modeled allowed
ancestor, and no qualifying `aria-owns` owner. One `aria-owns` owner may
supply a context directly or through its own modeled ancestor only when its
referenced target is a unique local ID, the owner has no
duplicate/missing/ambiguous `aria-owns` targets, and neither side is in an
`aria-hidden="true"` or `role="none"`/`role="presentation"`
relationship. This means a root-level role, hidden/presentational subtree,
ambiguous ownership graph, unknown owner role, and template content are
conservatively skipped rather than asserted invalid.

`aria-owns` that names a missing or duplicate local target is not a context
finding. `aria-idref-invalid` owns that relationship error; `duplicate-id`
owns the duplicate-ID diagnostic. Fragment references resolve only within the
fragment supplied to the audit API, so a component cannot prove ownership of
an element outside its input.

The recovered DOM and a limited implicit-role table are not a browser
accessibility tree. CSS display/visibility, script mutation, shadow DOM,
host-language mappings outside the listed elements, and platform accessibility
tree processing remain outside this rule. Verify uncertain widget containment
in a browser.

## Test and comparison evidence

The named MoonBit tests `required ARIA context accepts modeled DOM and native
implicit relationships`, `required ARIA context reports only determinable
missing recovered contexts`, `required ARIA context accepts one unique local
aria owns owner`, and `required ARIA context leaves ambiguous ownership to
IDREF validation` cover the table and its boundaries. The self-authored
`examples/comparison/aria-required-context-role.html` is suitable for a
development-only comparison with axe-core's `aria-required-parent`; see
`REFERENCE-COMPARISON.md` for the recorded status and intentional scope
difference.
