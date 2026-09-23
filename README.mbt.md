# A11yTrace

A11yTrace is a small, pure MoonBit library for statically checking HTML accessibility rules.

## Dependency and use

It uses [`bobzhang/html_parser` 0.1.8](https://github.com/bobzhang/html_parser) to parse HTML into a DOM; A11yTrace does not parse HTML with regular expressions.

```moonbit nocheck
import {
  "youyong5/a11ytrace" @a11ytrace,
}

match @a11ytrace.audit_html("<img src=\"logo.svg\">") {
  Findings(findings) => println(findings[0].element_path)
  FindingsWithParseErrors(findings, errors) => {
    println(findings[0].element_path)
    println(errors[0].message)
  }
  ParseErrors(errors) => println(errors[0].message)
}
```

`audit_html` does no file I/O, so callers choose where HTML comes from and how results are presented.

- A static-site generator can audit each rendered page before writing it.
- A documentation-site build can audit generated guide fragments.
- A frontend CI job can audit fixture or server-rendered HTML and fail on findings.

## Current rule and boundary

`img-alt-missing` reports an `<img>` that has no `alt` attribute. An explicit `alt=""` is accepted for decorative images, as is any non-empty `alt` value. The rule does not determine whether an image is decorative, whether alternative text is good, or whether a whole document conforms to WCAG.

`form-control-name-missing` reports unnamed `<input>`, `<select>`, and `<textarea>` controls, excluding hidden and button-like input types. It recognizes text-bearing labels, non-empty ARIA names, and `title` as a fallback; it does not implement the complete browser Accessible Name algorithm.

`link-name-missing` reports an `<a href>` without recognizable text, non-empty image alt text, ARIA name, or fallback title. It ignores script, style, and template text. It checks presence of a name, not whether the destination is described clearly; when no supported source is present, SVG-containing links are conservatively left unreported until SVG name sources are supported.

`button-name-missing` reports unnamed native `<button>`, `input[type="button"]`, and `input[type="image"]`; custom `role="button"` is outside this rule. It recognizes supported native text, image alt, value, ARIA, and title sources as appropriate, while leaving SVG-only native buttons unreported until SVG name sources are supported. It is a static name-presence check, not a WCAG conformance conclusion.

`heading-level-skipped` suggests reviewing a native heading that jumps down two or more levels from the preceding heading; the first heading may start at any level. `heading-name-missing` reports empty native headings unless supported text, image alt, or ARIA naming is present. Neither rule infers headings from visual styling or implements a complete browser Accessible Name algorithm.

For example, both rules can be reported from one fragment:

```moonbit nocheck
match @a11ytrace.audit_html("<img src=\"chart.svg\"><input placeholder=\"Email\">") {
  Findings(findings) => {
    // findings[0].rule_id == "img-alt-missing"
    // findings[1].rule_id == "form-control-name-missing"
  }
  FindingsWithParseErrors(findings, errors) => ()
  ParseErrors(errors) => ()
}
```

Current rules can be reported in document order:

```moonbit nocheck
match @a11ytrace.audit_html("<img src=\"chart.svg\"><input><a href=\"/details\"></a><button></button><h2>Section</h2><h4></h4>") {
  Findings(findings) => {
    // image, form, link, button, heading-level, and heading-name findings
  }
  FindingsWithParseErrors(findings, errors) => ()
  ParseErrors(errors) => ()
}
```

The parser uses HTML5-style recovery. Recoverable parser diagnostics produce `FindingsWithParseErrors`: the recovered DOM is still checked and diagnostics stay visible. `ParseErrors` is reserved for a parser failure that prevents a DOM audit. Findings include a deterministic CSS-style `element_path`; their optional line and column are source start-tag locations supplied by the parser, and remain absent when the parser has no source position.

See [RULES.md](RULES.md) for the rule rationale and the [W3C Images Tutorial](https://www.w3.org/WAI/tutorials/images/).

## License and attribution

A11yTrace's audit rules and library code are original work licensed under Apache-2.0 (see [LICENSE](LICENSE)). It depends on, but does not copy, `bobzhang/html_parser` 0.1.8, which is also Apache-2.0 licensed.
