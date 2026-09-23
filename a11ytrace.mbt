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
  collect_missing_alt_findings(parsed.root, "", findings)
  let diagnostics = parsed.errors.map(parse_diagnostic)
  if diagnostics.is_empty() {
    Findings(findings)
  } else {
    FindingsWithParseErrors(findings, diagnostics)
  }
}

///|
fn collect_missing_alt_findings(
  node : @dom.Node,
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
      collect_missing_alt_findings(child, path, findings)
    } else {
      collect_missing_alt_findings(child, parent_path, findings)
    }
    position = position + 1
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
