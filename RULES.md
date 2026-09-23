# Rules

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
