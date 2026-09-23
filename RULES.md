# Rules

## `img-alt-missing`

Reports an HTML `<img>` element that omits the `alt` attribute. The suggested repair is to add an appropriate `alt` attribute; `alt=""` is a valid explicit choice for a decorative image.

This rule is based on the guidance in the [W3C Images Tutorial](https://www.w3.org/WAI/tutorials/images/). It intentionally checks attribute presence only. It cannot judge an image's purpose or the quality of an alternative text, and it is not a conformance claim for a page or product.
