///|
/// A result produced by `audit_html`.
///
/// `FindingsWithParseErrors` preserves recoverable parser diagnostics while
/// still auditing the parser's recovered DOM. `ParseErrors` means the parser
/// could not return a DOM for auditing.
pub(all) enum AuditResult {
  Findings(Array[Finding])
  FindingsWithParseErrors(Array[Finding], Array[ParseDiagnostic])
  ParseErrors(Array[ParseDiagnostic])
}

///|
/// A single accessibility finding.
///
/// `element_path` is a deterministic CSS-style path based on element names and
/// `:nth-of-type()` positions. `line` and `column` are the parser's optional,
/// 1-based source location for the element start tag.
pub(all) struct Finding {
  rule_id : String
  message : String
  suggestion : String
  element_path : String
  line : Int?
  column : Int?
}

///|
/// A parse diagnostic reported before audit rules are evaluated.
pub(all) struct ParseDiagnostic {
  code : String
  message : String
  line : Int?
  column : Int?
}

///|
/// Audit an HTML fragment with the rules currently implemented by A11yTrace.
///
/// This is a pure operation: it performs no file I/O and can be used by a
/// build tool, test suite, or another MoonBit package. Input with parser
/// diagnostics returns `FindingsWithParseErrors`, so ordinary HTML5 recovery
/// does not hide rule findings. A parser failure returns `ParseErrors`.
pub fn audit_html(html : String) -> AuditResult {
  let parsed = @html_parser.parse_fragment(
    html,
    collect_errors=true,
    track_node_locations=true,
  ) catch {
    error => return ParseErrors([parse_failure(error)])
  }
  let findings = []
  collect_findings(parsed.root, parsed.root, "", findings)
  let diagnostics = parsed.errors.map(parse_diagnostic)
  if diagnostics.is_empty() {
    Findings(findings)
  } else {
    FindingsWithParseErrors(findings, diagnostics)
  }
}

///|
fn collect_findings(
  node : @dom.Node,
  document_root : @dom.Node,
  parent_path : String,
  findings : Array[Finding],
) -> Unit {
  let children = node.children()
  let mut position = 0
  while position < children.length() {
    let child = children[position]
    if child.kind() is @dom.Element {
      let name = child.name()
      let occurrence = nth_of_type(children, position, name)
      let path = if parent_path == "" {
        "\{name}:nth-of-type(\{occurrence})"
      } else {
        "\{parent_path} > \{name}:nth-of-type(\{occurrence})"
      }
      if name == "img" && child.attrs().get("alt") is None {
        findings.push(missing_alt_finding(child, path))
      }
      if is_form_control_to_check(child) &&
        !has_recognizable_form_control_name(child, document_root) {
        findings.push(missing_form_control_name_finding(child, path))
      }
      if is_link_to_check(child) &&
        !has_recognizable_link_name(child, document_root) {
        findings.push(missing_link_name_finding(child, path))
      }
      collect_findings(child, document_root, path, findings)
    } else {
      collect_findings(child, document_root, parent_path, findings)
    }
    position = position + 1
  }
}

///|
fn is_link_to_check(node : @dom.Node) -> Bool {
  node.name() == "a" && node.attrs().get("href") is Some(_)
}

///|
fn has_recognizable_link_name(
  link : @dom.Node,
  document_root : @dom.Node,
) -> Bool {
  has_nonempty_visible_text(link) ||
  has_nonempty_image_alt(link) ||
  has_nonempty_attribute(link, "aria-label") ||
  has_name_from_labelledby(link, document_root) ||
  has_nonempty_attribute(link, "title") ||
  has_potential_svg_name_source(link)
}

///|
fn has_nonempty_visible_text(node : @dom.Node) -> Bool {
  if node.kind() is @dom.Text {
    return !node.data().trim().is_empty()
  }
  if node.kind() is @dom.Element && is_non_name_text_element(node.name()) {
    return false
  }
  for child in node.children() {
    if has_nonempty_visible_text(child) {
      return true
    }
  }
  false
}

///|
fn is_non_name_text_element(name : String) -> Bool {
  name is ("script" | "style" | "template")
}

///|
fn has_nonempty_image_alt(node : @dom.Node) -> Bool {
  if node.kind() is @dom.Element &&
    node.name() == "img" &&
    has_nonempty_attribute(node, "alt") {
    return true
  }
  for child in node.children() {
    if has_nonempty_image_alt(child) {
      return true
    }
  }
  false
}

///|
fn has_potential_svg_name_source(node : @dom.Node) -> Bool {
  if node.kind() is @dom.Element && node.name() == "svg" {
    return true
  }
  for child in node.children() {
    if has_potential_svg_name_source(child) {
      return true
    }
  }
  false
}

///|
fn is_form_control_to_check(node : @dom.Node) -> Bool {
  match node.name() {
    "select" | "textarea" => true
    "input" =>
      match node.attrs().get("type") {
        Some(Some(type_)) => !is_excluded_input_type(type_)
        _ => true
      }
    _ => false
  }
}

///|
fn is_excluded_input_type(type_ : String) -> Bool {
  match type_.trim().to_lower() {
    "hidden" | "submit" | "reset" | "button" | "image" => true
    _ => false
  }
}

///|
fn has_recognizable_form_control_name(
  control : @dom.Node,
  document_root : @dom.Node,
) -> Bool {
  has_nonempty_attribute(control, "aria-label") ||
  has_nonempty_attribute(control, "title") ||
  has_name_from_labelledby(control, document_root) ||
  has_explicit_label(control, document_root) ||
  has_wrapping_label(control)
}

///|
fn has_nonempty_attribute(node : @dom.Node, name : String) -> Bool {
  match node.attrs().get(name) {
    Some(Some(value)) => !value.trim().is_empty()
    _ => false
  }
}

///|
fn has_name_from_labelledby(
  control : @dom.Node,
  document_root : @dom.Node,
) -> Bool {
  match control.attrs().get("aria-labelledby") {
    Some(Some(value)) => {
      let normalized = value
        .replace_all(old="\t", new=" ")
        .replace_all(old="\n", new=" ")
        .replace_all(old="\r", new=" ")
        .replace_all(old="\u{000C}", new=" ")
      for reference in normalized.split(" ") {
        let id = reference.trim()
        if !id.is_empty() && element_with_id_has_text(document_root, id) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn element_with_id_has_text(node : @dom.Node, id : StringView) -> Bool {
  if node.kind() is @dom.Element &&
    node.attrs().get("id") is Some(Some(node_id)) &&
    node_id[:] == id &&
    has_nonempty_visible_text(node) {
    return true
  }
  for child in node.children() {
    if element_with_id_has_text(child, id) {
      return true
    }
  }
  false
}

///|
fn has_explicit_label(control : @dom.Node, document_root : @dom.Node) -> Bool {
  match control.attrs().get("id") {
    Some(Some(id)) if !id.trim().is_empty() =>
      label_for_id_has_text(document_root, id)
    _ => false
  }
}

///|
fn label_for_id_has_text(node : @dom.Node, id : String) -> Bool {
  if node.kind() is @dom.Element &&
    node.name() == "label" &&
    node.attrs().get("for") is Some(Some(for_id)) &&
    for_id == id &&
    has_nonempty_visible_text(node) {
    return true
  }
  for child in node.children() {
    if label_for_id_has_text(child, id) {
      return true
    }
  }
  false
}

///|
fn has_wrapping_label(control : @dom.Node) -> Bool {
  let mut ancestor = control.parent()
  while ancestor is Some(node) {
    if node.kind() is @dom.Element &&
      node.name() == "label" &&
      has_nonempty_visible_text(node) &&
      wrapping_label_applies_to_control(node, control) {
      return true
    }
    ancestor = node.parent()
  }
  false
}

///|
fn wrapping_label_applies_to_control(
  label : @dom.Node,
  control : @dom.Node,
) -> Bool {
  match label.attrs().get("for") {
    None => true
    Some(Some(for_id)) =>
      match control.attrs().get("id") {
        Some(Some(control_id)) => for_id == control_id
        _ => false
      }
    Some(None) => false
  }
}

///|
fn parse_diagnostic(error : @html_parser.ParseError) -> ParseDiagnostic {
  {
    code: error.code,
    message: error.message,
    line: error.line,
    column: error.column,
  }
}

///|
fn parse_failure(error : @html_parser.HtmlError) -> ParseDiagnostic {
  match error {
    @html_parser.HtmlError::StrictMode(parse_error) =>
      parse_diagnostic(parse_error)
    @html_parser.HtmlError::InvalidSerialization(message) =>
      parser_failure_message(message)
    @html_parser.HtmlError::UnsafeHtml(message) =>
      parser_failure_message(message)
    @html_parser.HtmlError::SelectorError(message) =>
      parser_failure_message(message)
  }
}

///|
fn parser_failure_message(message : String) -> ParseDiagnostic {
  { code: "parser-failure", message, line: None, column: None, }
}

///|
fn missing_alt_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "img-alt-missing",
    message: "This image has no alt attribute.",
    suggestion: "Add an alt attribute; use alt=\"\" only when the image is decorative.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn missing_form_control_name_finding(
  node : @dom.Node,
  path : String,
) -> Finding {
  {
    rule_id: "form-control-name-missing",
    message: "This form control has no recognizable accessible name.",
    suggestion: "Add visible label text or a non-empty aria-label, aria-labelledby reference, or title.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn missing_link_name_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "link-name-missing",
    message: "This link has no recognizable accessible name.",
    suggestion: "Add link text, an image with non-empty alt text, aria-label, aria-labelledby, or title.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn nth_of_type(
  siblings : Array[@dom.Node],
  position : Int,
  name : String,
) -> Int {
  let mut count = 0
  let mut index = 0
  while index <= position {
    let sibling = siblings[index]
    if sibling.kind() is @dom.Element && sibling.name() == name {
      count = count + 1
    }
    index = index + 1
  }
  count
}
