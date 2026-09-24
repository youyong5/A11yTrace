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
/// The parser and finding status of a detailed audit.
pub(all) enum DetailedAuditStatus {
  Findings
  FindingsWithParseErrors
  ParseErrors
}

///|
/// A static check that requires browser, CSS, or runtime information before it
/// can be treated as a confirmed issue.
pub(all) struct ReviewItem {
  rule_id : String
  reason : String
  element_path : String
  line : Int?
  column : Int?
}

///|
/// A detailed audit result that keeps definite findings, parser diagnostics,
/// and manual-review items separate.
pub(all) struct DetailedAuditResult {
  status : DetailedAuditStatus
  findings : Array[Finding]
  parse_diagnostics : Array[ParseDiagnostic]
  review_items : Array[ReviewItem]
}

///|
/// A result produced by `audit_html_with_rules`.
pub(all) enum ConfiguredAuditResult {
  Audited(AuditResult)
  ConfigurationError(RuleConfigurationError)
}

///|
/// A result produced by a detailed rule-selected audit.
pub(all) enum DetailedConfiguredAuditResult {
  Audited(DetailedAuditResult)
  ConfigurationError(RuleConfigurationError)
}

///|
/// An invalid rule-selection configuration.
pub(all) enum RuleConfigurationError {
  UnknownRuleId(String)
}

///|
/// A broad grouping used by the stable rule directory.
pub(all) enum RuleCategory {
  ContentName
  DocumentStructure
  Interaction
  Relationships
  Aria
  Timing
}

///|
/// The input scope in which a rule is evaluated.
pub(all) enum RuleScope {
  Document
  Fragment
  DocumentOrFragment
}

///|
/// The confidence represented by a rule's output.
pub(all) enum RuleResultKind {
  ConfirmedFinding
  StaticHint
  ManualReview
}

///|
/// Stable, read-only metadata describing one built-in rule.
pub(all) struct RuleMetadata {
  id : String
  summary : String
  category : RuleCategory
  scope : RuleScope
  result_kind : RuleResultKind
  reference_url : String
  boundary : String
}

///|
/// Audit HTML with the rules currently implemented by A11yTrace.
///
/// This is a pure operation: it performs no file I/O and can be used by a
/// build tool, test suite, or another MoonBit package. Input with parser
/// diagnostics returns `FindingsWithParseErrors`, so ordinary HTML5 recovery
/// does not hide rule findings. A parser failure returns `ParseErrors`.
///
/// Inputs with an HTML document marker (`<!doctype` or `<html`) are parsed as
/// complete documents and run document-only rules. For compatibility, markup
/// without such a marker retains fragment-style parsing; use
/// `audit_html_fragment` to explicitly audit a component fragment.
pub fn audit_html(html : String) -> AuditResult {
  detailed_to_audit_result(
    audit_html_detailed_with_enabled_rules(
      html,
      all_rule_ids(),
      looks_like_html_document(html),
    ),
  )
}

///|
/// Audit HTML and keep definite findings separate from items needing browser
/// or CSS review. Unlike `audit_html`, this result exposes `review_items`.
pub fn audit_html_detailed(html : String) -> DetailedAuditResult {
  audit_html_detailed_with_enabled_rules(
    html,
    all_rule_ids(),
    looks_like_html_document(html),
  )
}

///|
/// Audit HTML with selected rules while retaining manual-review items.
/// Unknown IDs are returned before parsing, as with `audit_html_with_rules`.
pub fn audit_html_detailed_with_rules(
  html : String,
  enabled_rule_ids : Array[String],
) -> DetailedConfiguredAuditResult {
  audit_html_detailed_with_selected_rules(
    html,
    enabled_rule_ids,
    looks_like_html_document(html),
  )
}

///|
/// Return the stable IDs accepted by `audit_html_with_rules`.
pub fn available_rule_ids() -> Array[String] {
  all_rule_ids()
}

///|
/// Return copied metadata for every built-in rule in stable ID order.
pub fn available_rules() -> Array[RuleMetadata] {
  rule_catalog()
}

///|
/// Look up copied metadata for one built-in rule ID.
pub fn rule_metadata(rule_id : String) -> RuleMetadata? {
  for rule in rule_catalog() {
    if rule.id == rule_id {
      return Some(rule)
    }
  }
  None
}

///|
/// Return the content-name rule IDs as a convenient selection.
pub fn content_rule_ids() -> Array[String] {
  rule_ids_for_category(ContentName)
}

///|
/// Return the complete-document structural rule IDs as a convenient selection.
pub fn document_rule_ids() -> Array[String] {
  rule_catalog()
  .filter(fn(rule) { rule.scope is Document })
  .map(fn(rule) { rule.id })
}

///|
/// Return the rule IDs that can produce manual-review items.
pub fn review_rule_ids() -> Array[String] {
  rule_catalog()
  .filter(fn(rule) { rule.result_kind is ManualReview })
  .map(fn(rule) { rule.id })
}

///|
/// Audit HTML with only the selected rule IDs.
///
/// An empty array runs no rules but still returns parser diagnostics. Repeated
/// IDs are treated as one selection. An unknown ID returns
/// `ConfigurationError` before parsing.
pub fn audit_html_with_rules(
  html : String,
  enabled_rule_ids : Array[String],
) -> ConfiguredAuditResult {
  audit_html_with_selected_rules(
    html,
    enabled_rule_ids,
    looks_like_html_document(html),
  )
}

///|
/// Audit an HTML fragment with every current A11yTrace rule.
///
/// This is useful for a component or generated template that is not wrapped
/// in a complete document. Labels and ARIA references are resolved only
/// within the supplied fragment.
pub fn audit_html_fragment(fragment : String) -> AuditResult {
  detailed_to_audit_result(
    audit_html_detailed_with_enabled_rules(fragment, all_rule_ids(), false),
  )
}

///|
/// Audit an HTML fragment and keep manual-review items separate from definite
/// findings and parser diagnostics.
pub fn audit_html_fragment_detailed(fragment : String) -> DetailedAuditResult {
  audit_html_detailed_with_enabled_rules(fragment, all_rule_ids(), false)
}

///|
/// Audit a fragment with selected rules while retaining manual-review items.
pub fn audit_html_fragment_detailed_with_rules(
  fragment : String,
  enabled_rule_ids : Array[String],
) -> DetailedConfiguredAuditResult {
  audit_html_detailed_with_selected_rules(fragment, enabled_rule_ids, false)
}

///|
/// Audit an HTML fragment with only the selected rule IDs.
///
/// Its rule-selection and parser-diagnostic behavior matches
/// `audit_html_with_rules`. Unknown IDs return `ConfigurationError` before
/// parsing the fragment.
pub fn audit_html_fragment_with_rules(
  fragment : String,
  enabled_rule_ids : Array[String],
) -> ConfiguredAuditResult {
  audit_html_with_selected_rules(fragment, enabled_rule_ids, false)
}

///|
fn audit_html_with_selected_rules(
  source : String,
  enabled_rule_ids : Array[String],
  is_document : Bool,
) -> ConfiguredAuditResult {
  match unknown_rule_id(enabled_rule_ids) {
    Some(rule_id) => ConfigurationError(UnknownRuleId(rule_id))
    None =>
      Audited(
        detailed_to_audit_result(
          audit_html_detailed_with_enabled_rules(
            source, enabled_rule_ids, is_document,
          ),
        ),
      )
  }
}

///|
fn audit_html_detailed_with_selected_rules(
  source : String,
  enabled_rule_ids : Array[String],
  is_document : Bool,
) -> DetailedConfiguredAuditResult {
  match unknown_rule_id(enabled_rule_ids) {
    Some(rule_id) => ConfigurationError(UnknownRuleId(rule_id))
    None =>
      Audited(
        audit_html_detailed_with_enabled_rules(
          source, enabled_rule_ids, is_document,
        ),
      )
  }
}

///|
/// Render an audit result as a compact JSON document for programmatic use.
///
/// The JSON object always contains `status`, `findings`, and
/// `parse_diagnostics`. Optional source positions are rendered as JSON `null`
/// when the parser did not provide them.
pub fn render_audit_json(result : AuditResult) -> String {
  @json.to_json(audit_result_json(result)).stringify()
}

///|
/// Render a detailed audit result as compact JSON. It has the stable fields
/// `status`, `findings`, `parse_diagnostics`, and `review_items`.
pub fn render_detailed_audit_json(result : DetailedAuditResult) -> String {
  @json.to_json(detailed_audit_result_json(result)).stringify()
}

///|
fn audit_result_json(result : AuditResult) -> Json {
  match result {
    Findings(findings) =>
      {
        "status": "findings",
        "findings": findings.map(finding_json),
        "parse_diagnostics": [],
      }
    FindingsWithParseErrors(findings, diagnostics) =>
      {
        "status": "findings_with_parse_errors",
        "findings": findings.map(finding_json),
        "parse_diagnostics": diagnostics.map(parse_diagnostic_json),
      }
    ParseErrors(diagnostics) =>
      {
        "status": "parse_errors",
        "findings": [],
        "parse_diagnostics": diagnostics.map(parse_diagnostic_json),
      }
  }
}

///|
fn detailed_audit_result_json(result : DetailedAuditResult) -> Json {
  {
    "status": detailed_status_string(result.status),
    "findings": result.findings.map(finding_json),
    "parse_diagnostics": result.parse_diagnostics.map(parse_diagnostic_json),
    "review_items": result.review_items.map(review_item_json),
  }
}

///|
fn detailed_status_string(status : DetailedAuditStatus) -> String {
  match status {
    DetailedAuditStatus::Findings => "findings"
    DetailedAuditStatus::FindingsWithParseErrors => "findings_with_parse_errors"
    DetailedAuditStatus::ParseErrors => "parse_errors"
  }
}

///|
fn finding_json(finding : Finding) -> Json {
  {
    "rule_id": finding.rule_id,
    "message": finding.message,
    "suggestion": finding.suggestion,
    "element_path": finding.element_path,
    "line": optional_int_json(finding.line),
    "column": optional_int_json(finding.column),
  }
}

///|
fn parse_diagnostic_json(diagnostic : ParseDiagnostic) -> Json {
  {
    "code": diagnostic.code,
    "message": diagnostic.message,
    "line": optional_int_json(diagnostic.line),
    "column": optional_int_json(diagnostic.column),
  }
}

///|
fn review_item_json(item : ReviewItem) -> Json {
  {
    "rule_id": item.rule_id,
    "reason": item.reason,
    "element_path": item.element_path,
    "line": optional_int_json(item.line),
    "column": optional_int_json(item.column),
  }
}

///|
fn optional_int_json(value : Int?) -> Json {
  match value {
    Some(value) => @json.to_json(value)
    None => null
  }
}

///|
fn audit_html_detailed_with_enabled_rules(
  html : String,
  enabled_rule_ids : Array[String],
  is_document : Bool,
) -> DetailedAuditResult {
  let parsed = try {
    if is_document {
      @html_parser.parse(html, collect_errors=true, track_node_locations=true)
    } else {
      @html_parser.parse_fragment(
        html,
        collect_errors=true,
        track_node_locations=true,
      )
    }
  } catch {
    error =>
      return {
        status: DetailedAuditStatus::ParseErrors,
        findings: [],
        parse_diagnostics: [parse_failure(error)],
        review_items: [],
      }
  }
  let context = build_audit_context(parsed.root, is_document)
  let findings = []
  let review_items = []
  let seen_navigation_names : Array[String] = []
  ignore(
    collect_findings(
      parsed.root,
      "",
      None,
      findings,
      review_items,
      enabled_rule_ids,
      None,
      context,
      false,
      seen_navigation_names,
    ),
  )
  let diagnostics = parsed.errors.map(parse_diagnostic)
  let status = if diagnostics.is_empty() {
    DetailedAuditStatus::Findings
  } else {
    DetailedAuditStatus::FindingsWithParseErrors
  }
  { status, findings, parse_diagnostics: diagnostics, review_items, }
}

///|
fn detailed_to_audit_result(result : DetailedAuditResult) -> AuditResult {
  match result.status {
    DetailedAuditStatus::Findings => AuditResult::Findings(result.findings)
    DetailedAuditStatus::FindingsWithParseErrors =>
      AuditResult::FindingsWithParseErrors(
        result.findings,
        result.parse_diagnostics,
      )
    DetailedAuditStatus::ParseErrors =>
      AuditResult::ParseErrors(result.parse_diagnostics)
  }
}

///|
fn looks_like_html_document(source : String) -> Bool {
  let normalized = source.to_lower()
  normalized.contains("<!doctype") ||
  normalized.contains("<html>") ||
  normalized.contains("<html ") ||
  normalized.contains("<html\t") ||
  normalized.contains("<html\n") ||
  normalized.contains("<html\r")
}

///|
fn all_rule_ids() -> Array[String] {
  rule_catalog().map(fn(rule) { rule.id })
}

///|
fn rule_ids_for_category(category : RuleCategory) -> Array[String] {
  rule_catalog()
  .filter(fn(rule) { rule_category_matches(rule.category, category) })
  .map(fn(rule) { rule.id })
}

///|
fn rule_category_matches(left : RuleCategory, right : RuleCategory) -> Bool {
  match (left, right) {
    (ContentName, ContentName) => true
    (DocumentStructure, DocumentStructure) => true
    (Interaction, Interaction) => true
    (Relationships, Relationships) => true
    (Aria, Aria) => true
    (Timing, Timing) => true
    _ => false
  }
}

///|
fn rule_catalog() -> Array[RuleMetadata] {
  [
    {
      id: "img-alt-missing",
      summary: "Image omits alt.",
      category: ContentName,
      scope: DocumentOrFragment,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/WAI/tutorials/images/",
      boundary: "Checks alt presence, not image purpose or alternative-text quality.",
    },
    {
      id: "form-control-name-missing",
      summary: "Input control lacks a supported static name.",
      category: ContentName,
      scope: DocumentOrFragment,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/WAI/tutorials/forms/labels/",
      boundary: "Selected labels, ARIA, and title sources only; not full accessible-name computation.",
    },
    {
      id: "link-name-missing",
      summary: "Link with href lacks a supported static name.",
      category: ContentName,
      scope: DocumentOrFragment,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/WAI/standards-guidelines/act/rules/c487ae/",
      boundary: "Does not judge destination clarity and conservatively skips unresolved SVG naming.",
    },
    {
      id: "button-name-missing",
      summary: "Native button lacks a supported static name.",
      category: ContentName,
      scope: DocumentOrFragment,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/WAI/standards-guidelines/act/rules/97a4e1/",
      boundary: "Native buttons only; SVG-only naming and custom roles are outside scope.",
    },
    {
      id: "heading-level-skipped",
      summary: "Native heading skips downward levels.",
      category: DocumentStructure,
      scope: DocumentOrFragment,
      result_kind: StaticHint,
      reference_url: "https://www.w3.org/WAI/tutorials/page-structure/headings/",
      boundary: "A structure prompt only; first heading can be any level.",
    },
    {
      id: "heading-name-missing",
      summary: "Native heading lacks a supported static name.",
      category: ContentName,
      scope: DocumentOrFragment,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/WAI/tutorials/page-structure/headings/",
      boundary: "Does not infer visual headings or calculate all browser name sources.",
    },
    {
      id: "document-title-missing",
      summary: "Complete document has no non-empty title.",
      category: DocumentStructure,
      scope: Document,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/WAI/standards-guidelines/act/rules/2779a5/",
      boundary: "Checks static head title presence, not descriptive quality or uniqueness.",
    },
    {
      id: "html-lang-missing",
      summary: "Complete document html element lacks lang.",
      category: DocumentStructure,
      scope: Document,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/WAI/WCAG22/Understanding/language-of-page.html",
      boundary: "Does not validate language tags or infer text language.",
    },
    {
      id: "iframe-name-missing",
      summary: "Iframe lacks a supported static name.",
      category: ContentName,
      scope: DocumentOrFragment,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/WAI/standards-guidelines/act/rules/cae760/proposed/",
      boundary: "Checks title and selected ARIA sources only.",
    },
    {
      id: "duplicate-id",
      summary: "Later non-empty ID duplicates an earlier ID.",
      category: Relationships,
      scope: DocumentOrFragment,
      result_kind: ConfirmedFinding,
      reference_url: "https://html-validate.org/rules/no-dup-id.html",
      boundary: "Compares the recovered input scope; template descendants are excluded.",
    },
    {
      id: "reference-target-invalid",
      summary: "Selected ID reference has no unique local target.",
      category: Relationships,
      scope: DocumentOrFragment,
      result_kind: ConfirmedFinding,
      reference_url: "https://html-validate.org/rules/no-missing-references.html",
      boundary: "Covers label for, aria-labelledby, and aria-describedby only.",
    },
    {
      id: "table-headers-invalid",
      summary: "Table headers reference is not a unique same-table cell.",
      category: Relationships,
      scope: DocumentOrFragment,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/WAI/standards-guidelines/act/rules/a25f45/",
      boundary: "Does not determine semantic header quality or browser fallback association.",
    },
    {
      id: "area-alt-missing",
      summary: "Clickable image-map area lacks non-empty alt.",
      category: ContentName,
      scope: DocumentOrFragment,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/WAI/standards-guidelines/act/rules/c487ae/",
      boundary: "Only area elements with href are checked.",
    },
    {
      id: "aria-hidden-focus-review",
      summary: "Potential focus in an aria-hidden subtree needs browser review.",
      category: Aria,
      scope: DocumentOrFragment,
      result_kind: ManualReview,
      reference_url: "https://www.w3.org/WAI/standards-guidelines/act/rules/6cfa84/",
      boundary: "CSS, scripts, and sequential focus state are not statically known.",
    },
    {
      id: "body-aria-hidden",
      summary: "Document body is hidden from the accessibility tree.",
      category: Aria,
      scope: Document,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/WAI/standards-guidelines/act/rules/6cfa84/",
      boundary: "Checks only static body aria-hidden=true.",
    },
    {
      id: "multiple-main",
      summary: "Complete document has multiple native main landmarks.",
      category: DocumentStructure,
      scope: Document,
      result_kind: StaticHint,
      reference_url: "https://html-validate.org/rules/",
      boundary: "Native main only; it is a structure prompt, not a conformance verdict.",
    },
    {
      id: "navigation-landmark-name-missing",
      summary: "Repeated navigation landmark lacks a static distinguishing name.",
      category: DocumentStructure,
      scope: Document,
      result_kind: StaticHint,
      reference_url: "https://html-validate.org/rules/unique-landmark.html",
      boundary: "Native nav and selected static names only; SVG/runtime names become review items.",
    },
    {
      id: "navigation-landmark-name-duplicate",
      summary: "Repeated navigation landmark reuses a static name.",
      category: DocumentStructure,
      scope: Document,
      result_kind: StaticHint,
      reference_url: "https://html-validate.org/rules/unique-landmark.html",
      boundary: "Native nav and selected static names only.",
    },
    {
      id: "aria-abstract-role",
      summary: "Role attribute contains an ARIA 1.2 abstract role.",
      category: Aria,
      scope: DocumentOrFragment,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/TR/wai-aria-1.2/#role_definitions",
      boundary: "Does not validate all roles, permissions, or fallback processing.",
    },
    {
      id: "meta-refresh-delay",
      summary: "Meta refresh uses a supported non-zero delay.",
      category: Timing,
      scope: Document,
      result_kind: ConfirmedFinding,
      reference_url: "https://html-validate.org/rules/meta-refresh.html",
      boundary: "Recognizes only numeric content delays; refresh-loop and long-delay policy are outside scope.",
    },
    {
      id: "aria-state-value-invalid",
      summary: "Selected ARIA state has an invalid static token.",
      category: Aria,
      scope: DocumentOrFragment,
      result_kind: ConfirmedFinding,
      reference_url: "https://www.w3.org/WAI/standards-guidelines/act/rules/6a7281/",
      boundary: "Only documented boolean, tristate, and aria-current tokens are checked.",
    },
    {
      id: "button-implicit-submit",
      summary: "Form button omits an explicit type.",
      category: Interaction,
      scope: DocumentOrFragment,
      result_kind: StaticHint,
      reference_url: "https://html-validate.org/rules/no-implicit-button-type.html",
      boundary: "Only native buttons with missing or empty type inside a form are prompted.",
    },
  ]
}

///|
fn unknown_rule_id(rule_ids : Array[String]) -> String? {
  for rule_id in rule_ids {
    if !is_available_rule_id(rule_id) {
      return Some(rule_id)
    }
  }
  None
}

///|
fn is_available_rule_id(rule_id : String) -> Bool {
  rule_catalog().any(fn(rule) { rule.id == rule_id })
}

///|
fn is_rule_enabled(enabled_rule_ids : Array[String], rule_id : String) -> Bool {
  for enabled_rule_id in enabled_rule_ids {
    if enabled_rule_id == rule_id {
      return true
    }
  }
  false
}

///|
priv struct AuditContext {
  id_nodes : Map[String, Array[@dom.Node]]
  id_paths : Map[String, Array[String]]
  id_table_paths : Map[String, Array[String?]]
  labels_by_for : Map[String, Array[@dom.Node]]
  page_has_nonempty_title : Bool
  first_page_title_path : String?
  main_paths : Array[String]
  navigation_nodes : Array[(@dom.Node, String)]
  is_document : Bool
}

///|
fn build_audit_context(root : @dom.Node, is_document : Bool) -> AuditContext {
  let id_nodes : Map[String, Array[@dom.Node]] = Map([])
  let id_paths : Map[String, Array[String]] = Map([])
  let id_table_paths : Map[String, Array[String?]] = Map([])
  let labels_by_for : Map[String, Array[@dom.Node]] = Map([])
  let page_titles : Array[(@dom.Node, String)] = []
  let main_paths : Array[String] = []
  let navigation_nodes : Array[(@dom.Node, String)] = []
  index_context_children(
    root,
    "",
    false,
    None,
    id_nodes,
    id_paths,
    id_table_paths,
    labels_by_for,
    page_titles,
    main_paths,
    navigation_nodes,
  )
  let mut page_has_nonempty_title = false
  let mut first_page_title_path = None
  if is_document {
    for entry in page_titles {
      let (title, path) = entry
      if first_page_title_path is None {
        first_page_title_path = Some(path)
      }
      if has_nonempty_visible_text(title) {
        page_has_nonempty_title = true
      }
    }
  }
  {
    id_nodes,
    id_paths,
    id_table_paths,
    labels_by_for,
    page_has_nonempty_title,
    first_page_title_path,
    main_paths,
    navigation_nodes,
    is_document,
  }
}

///|
fn index_context_children(
  node : @dom.Node,
  parent_path : String,
  inside_head : Bool,
  enclosing_table_path : String?,
  id_nodes : Map[String, Array[@dom.Node]],
  id_paths : Map[String, Array[String]],
  id_table_paths : Map[String, Array[String?]],
  labels_by_for : Map[String, Array[@dom.Node]],
  page_titles : Array[(@dom.Node, String)],
  main_paths : Array[String],
  navigation_nodes : Array[(@dom.Node, String)],
) -> Unit {
  let children = node.children()
  let mut position = 0
  while position < children.length() {
    let child = children[position]
    if child.kind() is @dom.Element {
      let name = child.name()
      let occurrence = nth_of_type(children, position, name)
      let path = child_path(parent_path, name, occurrence)
      index_context_element(
        child, path, enclosing_table_path, id_nodes, id_paths, id_table_paths, labels_by_for,
      )
      let child_inside_head = inside_head || name == "head"
      let child_table_path = if name == "table" {
        Some(path)
      } else {
        enclosing_table_path
      }
      if child_inside_head && name == "title" {
        page_titles.push((child, path))
      }
      if name == "main" {
        main_paths.push(path)
      }
      if name == "nav" {
        navigation_nodes.push((child, path))
      }
      // Template contents are inert markup, not part of this audit's input
      // scope. The template element itself can still be indexed.
      if name != "template" {
        index_context_children(
          child, path, child_inside_head, child_table_path, id_nodes, id_paths, id_table_paths,
          labels_by_for, page_titles, main_paths, navigation_nodes,
        )
      }
    } else {
      index_context_children(
        child, parent_path, inside_head, enclosing_table_path, id_nodes, id_paths,
        id_table_paths, labels_by_for, page_titles, main_paths, navigation_nodes,
      )
    }
    position = position + 1
  }
}

///|
fn index_context_element(
  node : @dom.Node,
  path : String,
  enclosing_table_path : String?,
  id_nodes : Map[String, Array[@dom.Node]],
  id_paths : Map[String, Array[String]],
  id_table_paths : Map[String, Array[String?]],
  labels_by_for : Map[String, Array[@dom.Node]],
) -> Unit {
  match node.attrs().get("id") {
    Some(Some(id)) if !id.trim().is_empty() => {
      append_index_node(id_nodes, id, node)
      append_index_path(id_paths, id, path)
      append_index_table_path(id_table_paths, id, enclosing_table_path)
    }
    _ => ()
  }
  if node.name() == "label" {
    match node.attrs().get("for") {
      Some(Some(id)) if !id.trim().is_empty() =>
        append_index_node(labels_by_for, id, node)
      _ => ()
    }
  }
}

///|
fn append_index_node(
  index : Map[String, Array[@dom.Node]],
  key : String,
  node : @dom.Node,
) -> Unit {
  match index.get(key) {
    Some(nodes) => nodes.push(node)
    None => index[key] = [node]
  }
}

///|
fn append_index_path(
  index : Map[String, Array[String]],
  key : String,
  path : String,
) -> Unit {
  match index.get(key) {
    Some(paths) => paths.push(path)
    None => index[key] = [path]
  }
}

///|
fn append_index_table_path(
  index : Map[String, Array[String?]],
  key : String,
  table_path : String?,
) -> Unit {
  match index.get(key) {
    Some(paths) => paths.push(table_path)
    None => index[key] = [table_path]
  }
}

///|
fn collect_findings(
  node : @dom.Node,
  parent_path : String,
  enclosing_table_path : String?,
  findings : Array[Finding],
  review_items : Array[ReviewItem],
  enabled_rule_ids : Array[String],
  previous_heading_level : Int?,
  context : AuditContext,
  aria_hidden_ancestor : Bool,
  seen_navigation_names : Array[String],
) -> Int? {
  let children = node.children()
  let mut last_heading_level = previous_heading_level
  let mut position = 0
  while position < children.length() {
    let child = children[position]
    if child.kind() is @dom.Element {
      let name = child.name()
      let occurrence = nth_of_type(children, position, name)
      let path = child_path(parent_path, name, occurrence)
      let child_table_path = if name == "table" {
        Some(path)
      } else {
        enclosing_table_path
      }
      let hidden_by_aria = aria_hidden_ancestor || has_aria_hidden_true(child)
      if context.is_document && name == "html" {
        if is_rule_enabled(enabled_rule_ids, "html-lang-missing") &&
          !has_nonempty_attribute(child, "lang") {
          findings.push(missing_html_lang_finding(child, path))
        }
        if is_rule_enabled(enabled_rule_ids, "document-title-missing") &&
          !context.page_has_nonempty_title &&
          context.first_page_title_path is None {
          findings.push(missing_document_title_finding(child, path))
        }
      }
      if context.is_document &&
        name == "body" &&
        is_rule_enabled(enabled_rule_ids, "body-aria-hidden") &&
        has_aria_hidden_true(child) {
        findings.push(body_aria_hidden_finding(child, path))
      }
      if context.is_document &&
        name == "main" &&
        is_rule_enabled(enabled_rule_ids, "multiple-main") &&
        context.main_paths.length() > 1 &&
        context.main_paths[0] != path {
        findings.push(multiple_main_finding(child, path))
      }
      if context.is_document &&
        name == "nav" &&
        context.navigation_nodes.length() > 1 {
        collect_navigation_landmark_findings(
          child, path, findings, review_items, enabled_rule_ids, context, seen_navigation_names,
        )
      }
      if is_rule_enabled(enabled_rule_ids, "aria-abstract-role") &&
        has_abstract_role_token(child) {
        findings.push(abstract_role_finding(child, path))
      }
      if is_rule_enabled(enabled_rule_ids, "aria-state-value-invalid") &&
        has_invalid_selected_aria_state(child) {
        findings.push(invalid_aria_state_value_finding(child, path))
      }
      if context.is_document &&
        is_rule_enabled(enabled_rule_ids, "meta-refresh-delay") &&
        has_supported_nonzero_meta_refresh_delay(child) {
        findings.push(meta_refresh_delay_finding(child, path))
      }
      if is_rule_enabled(enabled_rule_ids, "aria-hidden-focus-review") &&
        hidden_by_aria &&
        is_potentially_focusable(child) {
        review_items.push(aria_hidden_focus_review_item(child, path))
      }
      if context.is_document &&
        name == "title" &&
        is_rule_enabled(enabled_rule_ids, "document-title-missing") &&
        !context.page_has_nonempty_title &&
        context.first_page_title_path is Some(title_path) &&
        path == title_path {
        findings.push(missing_document_title_finding(child, path))
      }
      if is_rule_enabled(enabled_rule_ids, "img-alt-missing") &&
        name == "img" &&
        child.attrs().get("alt") is None {
        findings.push(missing_alt_finding(child, path))
      }
      if is_rule_enabled(enabled_rule_ids, "duplicate-id") &&
        is_later_duplicate_id(child, path, context) {
        findings.push(duplicate_id_finding(child, path))
      }
      if is_rule_enabled(enabled_rule_ids, "reference-target-invalid") &&
        has_invalid_reference_target(child, context) {
        findings.push(invalid_reference_target_finding(child, path))
      }
      if is_rule_enabled(enabled_rule_ids, "form-control-name-missing") &&
        is_form_control_to_check(child) &&
        !has_recognizable_form_control_name(child, context) {
        findings.push(missing_form_control_name_finding(child, path))
      }
      if is_rule_enabled(enabled_rule_ids, "link-name-missing") &&
        is_link_to_check(child) &&
        !has_recognizable_link_name(child, context) {
        findings.push(missing_link_name_finding(child, path))
      }
      if is_rule_enabled(enabled_rule_ids, "button-name-missing") &&
        is_button_to_check(child) &&
        !has_recognizable_button_name(child, context) {
        findings.push(missing_button_name_finding(child, path))
      }
      if is_rule_enabled(enabled_rule_ids, "button-implicit-submit") &&
        name == "button" &&
        has_implicit_submit_type(child) &&
        has_form_ancestor(child) {
        findings.push(implicit_submit_button_finding(child, path))
      }
      if is_rule_enabled(enabled_rule_ids, "iframe-name-missing") &&
        name == "iframe" &&
        !has_recognizable_iframe_name(child, context) {
        findings.push(missing_iframe_name_finding(child, path))
      }
      if is_rule_enabled(enabled_rule_ids, "area-alt-missing") &&
        is_clickable_area(child) &&
        !has_nonempty_attribute(child, "alt") {
        findings.push(missing_area_alt_finding(child, path))
      }
      if is_rule_enabled(enabled_rule_ids, "table-headers-invalid") &&
        is_table_cell(child) &&
        enclosing_table_path is Some(_) &&
        has_invalid_table_headers(child, enclosing_table_path, context) {
        findings.push(invalid_table_headers_finding(child, path))
      }
      match heading_level(child) {
        Some(level) => {
          if is_rule_enabled(enabled_rule_ids, "heading-level-skipped") &&
            last_heading_level is Some(previous) &&
            level >= previous + 2 {
            findings.push(skipped_heading_level_finding(child, path))
          }
          last_heading_level = Some(level)
          if is_rule_enabled(enabled_rule_ids, "heading-name-missing") &&
            !has_recognizable_heading_name(child, context) {
            findings.push(missing_heading_name_finding(child, path))
          }
        }
        None => ()
      }
      if name != "template" {
        last_heading_level = collect_findings(
          child, path, child_table_path, findings, review_items, enabled_rule_ids,
          last_heading_level, context, hidden_by_aria, seen_navigation_names,
        )
      }
    } else {
      last_heading_level = collect_findings(
        child, parent_path, enclosing_table_path, findings, review_items, enabled_rule_ids,
        last_heading_level, context, aria_hidden_ancestor, seen_navigation_names,
      )
    }
    position = position + 1
  }
  last_heading_level
}

///|
fn has_aria_hidden_true(node : @dom.Node) -> Bool {
  match node.attrs().get("aria-hidden") {
    Some(Some(value)) => value.trim().to_lower() == "true"
    _ => false
  }
}

///|
fn is_potentially_focusable(node : @dom.Node) -> Bool {
  has_explicit_tabindex(node) || is_natively_focusable(node)
}

///|
fn has_explicit_tabindex(node : @dom.Node) -> Bool {
  match node.attrs().get("tabindex") {
    Some(Some(value)) => !value.trim().is_empty()
    _ => false
  }
}

///|
fn is_natively_focusable(node : @dom.Node) -> Bool {
  match node.name() {
    "a" | "area" => node.attrs().get("href") is Some(_)
    "button" | "select" | "textarea" => !has_disabled_attribute(node)
    "input" =>
      if has_disabled_attribute(node) {
        false
      } else {
        match node.attrs().get("type") {
          Some(Some(type_)) => type_.trim().to_lower() != "hidden"
          _ => true
        }
      }
    "summary" => true
    "audio" | "video" => node.attrs().get("controls") is Some(_)
    "iframe" => true
    _ => false
  }
}

///|
fn has_disabled_attribute(node : @dom.Node) -> Bool {
  node.attrs().get("disabled") is Some(_)
}

///|
fn collect_navigation_landmark_findings(
  node : @dom.Node,
  path : String,
  findings : Array[Finding],
  review_items : Array[ReviewItem],
  enabled_rule_ids : Array[String],
  context : AuditContext,
  seen_names : Array[String],
) -> Unit {
  match static_landmark_name(node, context) {
    Some(name) => {
      if is_rule_enabled(enabled_rule_ids, "navigation-landmark-name-duplicate") &&
        seen_names.contains(name) {
        findings.push(duplicate_navigation_landmark_name_finding(node, path))
      }
      seen_names.push(name)
    }
    None =>
      if has_potential_svg_name_source(node) {
        if is_rule_enabled(enabled_rule_ids, "navigation-landmark-name-missing") {
          review_items.push(navigation_landmark_name_review_item(node, path))
        }
      } else if is_rule_enabled(
          enabled_rule_ids, "navigation-landmark-name-missing",
        ) {
        findings.push(missing_navigation_landmark_name_finding(node, path))
      }
  }
}

///|
fn static_landmark_name(node : @dom.Node, context : AuditContext) -> String? {
  match static_name_from_labelledby(node, context) {
    Some(name) => Some(name)
    None =>
      match node.attrs().get("aria-label") {
        Some(Some(name)) if !name.trim().is_empty() =>
          Some(name.trim().to_owned())
        _ =>
          match node.attrs().get("title") {
            Some(Some(name)) if !name.trim().is_empty() =>
              Some(name.trim().to_owned())
            _ => None
          }
      }
  }
}

///|
fn static_name_from_labelledby(
  node : @dom.Node,
  context : AuditContext,
) -> String? {
  match node.attrs().get("aria-labelledby") {
    Some(Some(value)) => {
      let output = StringBuilder()
      for id in idref_tokens(value) {
        match context.id_nodes.get(id) {
          Some([target]) => {
            let text = static_text_content(target)
            if !text.trim().is_empty() {
              if !output.to_string().is_empty() {
                output.write_string(" ")
              }
              output.write_string(text.trim().to_owned())
            }
          }
          _ => ()
        }
      }
      let name = output.to_string().trim().to_owned()
      if name.is_empty() {
        None
      } else {
        Some(name)
      }
    }
    _ => None
  }
}

///|
fn static_text_content(node : @dom.Node) -> String {
  let output = StringBuilder()
  append_static_text_content(node, output)
  output.to_string()
}

///|
fn append_static_text_content(node : @dom.Node, output : StringBuilder) -> Unit {
  if node.kind() is @dom.Text {
    output.write_string(node.data())
    return
  }
  if node.kind() is @dom.Element && is_non_name_text_element(node.name()) {
    return
  }
  if node.kind() is @dom.Element && node.name() == "img" {
    match node.attrs().get("alt") {
      Some(Some(alt)) if !alt.trim().is_empty() =>
        output.write_string(alt.trim().to_owned())
      _ => ()
    }
  }
  for child in node.children() {
    append_static_text_content(child, output)
  }
}

///|
fn has_abstract_role_token(node : @dom.Node) -> Bool {
  match node.attrs().get("role") {
    Some(Some(value)) => idref_tokens(value).any(is_abstract_aria_role)
    _ => false
  }
}

///|
fn is_abstract_aria_role(role : String) -> Bool {
  role.to_lower()
  is ("command"
  | "composite"
  | "input"
  | "landmark"
  | "range"
  | "roletype"
  | "section"
  | "sectionhead"
  | "select"
  | "structure"
  | "widget"
  | "window")
}

///|
fn has_supported_nonzero_meta_refresh_delay(node : @dom.Node) -> Bool {
  if node.name() != "meta" {
    return false
  }
  match (node.attrs().get("http-equiv"), node.attrs().get("content")) {
    (Some(Some(http_equiv)), Some(Some(content))) if http_equiv
      .trim()
      .to_lower() ==
      "refresh" => {
      let mut delay = ""
      for part in content.split(";") {
        delay = part.trim().to_owned()
        break
      }
      is_supported_nonzero_decimal(delay)
    }
    _ => false
  }
}

///|
fn is_supported_nonzero_decimal(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  let non_decimal = value
    .replace_all(old="0", new="")
    .replace_all(old="1", new="")
    .replace_all(old="2", new="")
    .replace_all(old="3", new="")
    .replace_all(old="4", new="")
    .replace_all(old="5", new="")
    .replace_all(old="6", new="")
    .replace_all(old="7", new="")
    .replace_all(old="8", new="")
    .replace_all(old="9", new="")
    .replace_all(old=".", new="")
  if !non_decimal.is_empty() {
    return false
  }
  let nonzero = value.replace_all(old="0", new="").replace_all(old=".", new="")
  !nonzero.is_empty()
}

///|
fn has_invalid_selected_aria_state(node : @dom.Node) -> Bool {
  has_invalid_aria_token(node, "aria-busy", is_true_false) ||
  has_invalid_aria_token(node, "aria-disabled", is_true_false) ||
  has_invalid_aria_token(node, "aria-expanded", is_true_false_or_undefined) ||
  has_invalid_aria_token(node, "aria-hidden", is_true_false_or_undefined) ||
  has_invalid_aria_token(node, "aria-modal", is_true_false) ||
  has_invalid_aria_token(node, "aria-multiline", is_true_false) ||
  has_invalid_aria_token(node, "aria-multiselectable", is_true_false) ||
  has_invalid_aria_token(node, "aria-readonly", is_true_false) ||
  has_invalid_aria_token(node, "aria-required", is_true_false) ||
  has_invalid_aria_token(node, "aria-checked", is_tristate) ||
  has_invalid_aria_token(node, "aria-pressed", is_tristate) ||
  has_invalid_aria_token(node, "aria-current", is_current_token) ||
  has_invalid_aria_token(node, "aria-invalid", is_invalid_token)
}

///|
fn has_invalid_aria_token(
  node : @dom.Node,
  attribute : String,
  is_allowed : (String) -> Bool,
) -> Bool {
  match node.attrs().get(attribute) {
    Some(Some(value)) if !value.trim().is_empty() =>
      !is_allowed(value.trim().to_lower().to_owned())
    _ => false
  }
}

///|
fn is_true_false(value : String) -> Bool {
  value is ("true" | "false")
}

///|
fn is_true_false_or_undefined(value : String) -> Bool {
  value is ("true" | "false" | "undefined")
}

///|
fn is_tristate(value : String) -> Bool {
  value is ("true" | "false" | "mixed" | "undefined")
}

///|
fn is_current_token(value : String) -> Bool {
  value is ("false" | "true" | "page" | "step" | "location" | "date" | "time")
}

///|
fn is_invalid_token(value : String) -> Bool {
  value is ("false" | "true" | "grammar" | "spelling")
}

///|
fn heading_level(node : @dom.Node) -> Int? {
  match node.name() {
    "h1" => Some(1)
    "h2" => Some(2)
    "h3" => Some(3)
    "h4" => Some(4)
    "h5" => Some(5)
    "h6" => Some(6)
    _ => None
  }
}

///|
fn has_recognizable_heading_name(
  heading : @dom.Node,
  context : AuditContext,
) -> Bool {
  has_nonempty_visible_text(heading) ||
  has_nonempty_image_alt(heading) ||
  has_nonempty_attribute(heading, "aria-label") ||
  has_name_from_labelledby(heading, context) ||
  has_potential_svg_name_source(heading)
}

///|
fn is_button_to_check(node : @dom.Node) -> Bool {
  match node.name() {
    "button" => true
    "input" =>
      match node.attrs().get("type") {
        Some(Some(type_)) => type_.trim().to_lower() is ("button" | "image")
        _ => false
      }
    _ => false
  }
}

///|
fn has_implicit_submit_type(button : @dom.Node) -> Bool {
  match button.attrs().get("type") {
    None => true
    Some(Some(value)) => value.trim().is_empty()
    Some(None) => true
  }
}

///|
fn has_form_ancestor(node : @dom.Node) -> Bool {
  let mut ancestor = node.parent()
  while ancestor is Some(parent) {
    if parent.kind() is @dom.Element && parent.name() == "form" {
      return true
    }
    ancestor = parent.parent()
  }
  false
}

///|
fn has_recognizable_button_name(
  button : @dom.Node,
  context : AuditContext,
) -> Bool {
  match button.name() {
    "button" =>
      has_nonempty_visible_text(button) ||
      has_nonempty_image_alt(button) ||
      has_nonempty_attribute(button, "aria-label") ||
      has_name_from_labelledby(button, context) ||
      has_nonempty_attribute(button, "title") ||
      has_potential_svg_name_source(button)
    "input" =>
      match button.attrs().get("type") {
        Some(Some(type_)) =>
          match type_.trim().to_lower() {
            "button" =>
              has_nonempty_attribute(button, "value") ||
              has_nonempty_attribute(button, "aria-label") ||
              has_name_from_labelledby(button, context) ||
              has_nonempty_attribute(button, "title")
            "image" =>
              has_nonempty_attribute(button, "alt") ||
              has_nonempty_attribute(button, "aria-label") ||
              has_name_from_labelledby(button, context) ||
              has_nonempty_attribute(button, "title")
            _ => false
          }
        _ => false
      }
    _ => false
  }
}

///|
fn is_link_to_check(node : @dom.Node) -> Bool {
  node.name() == "a" && node.attrs().get("href") is Some(_)
}

///|
fn is_clickable_area(node : @dom.Node) -> Bool {
  node.name() == "area" && node.attrs().get("href") is Some(_)
}

///|
fn is_table_cell(node : @dom.Node) -> Bool {
  node.name() is ("td" | "th")
}

///|
fn has_invalid_table_headers(
  cell : @dom.Node,
  enclosing_table_path : String?,
  context : AuditContext,
) -> Bool {
  match cell.attrs().get("headers") {
    Some(Some(value)) => {
      let cell_id = match cell.attrs().get("id") {
        Some(Some(id)) => Some(id)
        _ => None
      }
      for id in idref_tokens(value) {
        if (cell_id is Some(own_id) && id == own_id) ||
          !is_same_table_cell_target(context, id, enclosing_table_path) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn is_same_table_cell_target(
  context : AuditContext,
  id : String,
  source_table_path : String?,
) -> Bool {
  match context.id_nodes.get(id) {
    Some([target]) =>
      match context.id_table_paths.get(id) {
        Some([Some(target_table_path)]) =>
          source_table_path is Some(source_table_path) &&
          source_table_path == target_table_path &&
          is_table_cell(target)
        _ => false
      }
    _ => false
  }
}

///|
fn has_recognizable_iframe_name(
  iframe : @dom.Node,
  context : AuditContext,
) -> Bool {
  has_nonempty_attribute(iframe, "aria-label") ||
  has_name_from_labelledby(iframe, context) ||
  has_nonempty_attribute(iframe, "title")
}

///|
fn has_recognizable_link_name(link : @dom.Node, context : AuditContext) -> Bool {
  has_nonempty_visible_text(link) ||
  has_nonempty_image_alt(link) ||
  has_nonempty_attribute(link, "aria-label") ||
  has_name_from_labelledby(link, context) ||
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
  context : AuditContext,
) -> Bool {
  has_nonempty_attribute(control, "aria-label") ||
  has_nonempty_attribute(control, "title") ||
  has_name_from_labelledby(control, context) ||
  has_explicit_label(control, context) ||
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
  context : AuditContext,
) -> Bool {
  match control.attrs().get("aria-labelledby") {
    Some(Some(value)) => {
      for id in idref_tokens(value) {
        if indexed_id_has_static_text(context, id) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn idref_tokens(value : String) -> Array[String] {
  let normalized = value
    .replace_all(old="\t", new=" ")
    .replace_all(old="\n", new=" ")
    .replace_all(old="\r", new=" ")
    .replace_all(old="\u{000C}", new=" ")
  let tokens : Array[String] = []
  for token in normalized.split(" ") {
    let id = token.trim()
    let owned_id = id.to_owned()
    if !id.is_empty() && !tokens.contains(owned_id) {
      tokens.push(owned_id)
    }
  }
  tokens
}

///|
fn indexed_id_has_static_text(context : AuditContext, id : String) -> Bool {
  match context.id_nodes.get(id) {
    Some([target]) => has_nonempty_visible_text(target)
    _ => false
  }
}

///|
fn has_unique_id_target(context : AuditContext, id : String) -> Bool {
  context.id_nodes.get(id) is Some([_])
}

///|
fn has_invalid_reference_target(
  node : @dom.Node,
  context : AuditContext,
) -> Bool {
  (
    node.name() == "label" &&
    has_invalid_single_id_reference(node, "for", context)
  ) ||
  has_invalid_idref_list(node, "aria-labelledby", context) ||
  has_invalid_idref_list(node, "aria-describedby", context)
}

///|
fn has_invalid_single_id_reference(
  node : @dom.Node,
  attribute : String,
  context : AuditContext,
) -> Bool {
  match node.attrs().get(attribute) {
    Some(Some(id)) => {
      let trimmed = id.trim()
      !trimmed.is_empty() && !has_unique_id_target(context, trimmed.to_owned())
    }
    _ => false
  }
}

///|
fn has_invalid_idref_list(
  node : @dom.Node,
  attribute : String,
  context : AuditContext,
) -> Bool {
  match node.attrs().get(attribute) {
    Some(Some(value)) =>
      idref_tokens(value).any(fn(id) { !has_unique_id_target(context, id) })
    _ => false
  }
}

///|
fn has_explicit_label(control : @dom.Node, context : AuditContext) -> Bool {
  match control.attrs().get("id") {
    Some(Some(id)) if !id.trim().is_empty() =>
      indexed_label_for_id_has_text(context, id)
    _ => false
  }
}

///|
fn indexed_label_for_id_has_text(context : AuditContext, id : String) -> Bool {
  match context.id_nodes.get(id) {
    Some([_]) =>
      match context.labels_by_for.get(id) {
        Some(labels) => labels.any(has_nonempty_visible_text)
        None => false
      }
    _ => false
  }
}

///|
fn is_later_duplicate_id(
  node : @dom.Node,
  path : String,
  context : AuditContext,
) -> Bool {
  match node.attrs().get("id") {
    Some(Some(id)) if !id.trim().is_empty() =>
      match context.id_paths.get(id) {
        Some(paths) => paths.length() > 1 && paths[0] != path
        None => false
      }
    _ => false
  }
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
fn missing_document_title_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "document-title-missing",
    message: "This HTML document has no non-empty title.",
    suggestion: "Add a non-empty <title> in the document head that identifies the page.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn missing_html_lang_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "html-lang-missing",
    message: "This HTML document has no non-empty lang attribute on its html element.",
    suggestion: "Add a non-empty lang attribute to the document's <html> element, such as lang=\"en\".",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn meta_refresh_delay_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "meta-refresh-delay",
    message: "This meta refresh uses a non-zero delay.",
    suggestion: "Avoid timed refreshes; if a static redirect is necessary, use an immediate 0-second redirect.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn invalid_aria_state_value_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "aria-state-value-invalid",
    message: "This element has an invalid value for a selected ARIA state.",
    suggestion: "Use the documented token for the ARIA attribute, or remove the attribute when it is not applicable.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn missing_iframe_name_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "iframe-name-missing",
    message: "This iframe has no recognizable accessible name in static markup.",
    suggestion: "Add a non-empty title, aria-label, or aria-labelledby reference.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn duplicate_id_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "duplicate-id",
    message: "This id value duplicates an earlier id in the audited input scope.",
    suggestion: "Make each non-empty id unique within this document or fragment input.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn invalid_reference_target_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "reference-target-invalid",
    message: "This element references one or more missing or ambiguous ID targets.",
    suggestion: "Reference a unique non-empty id in the same audited input scope.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn invalid_table_headers_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "table-headers-invalid",
    message: "This table cell has a headers reference that is missing, self-referential, ambiguous, or outside its table.",
    suggestion: "Reference unique IDs of other cells in the same table.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn missing_area_alt_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "area-alt-missing",
    message: "This clickable image-map area has no non-empty alt text.",
    suggestion: "Add non-empty alt text that identifies this area's destination or action.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn body_aria_hidden_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "body-aria-hidden",
    message: "This document hides its body from the accessibility tree.",
    suggestion: "Remove aria-hidden=\"true\" from body and hide only the specific inactive content when appropriate.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn multiple_main_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "multiple-main",
    message: "This document has more than one main element.",
    suggestion: "Review the page structure and keep one primary main landmark unless a documented exception applies.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn missing_navigation_landmark_name_finding(
  node : @dom.Node,
  path : String,
) -> Finding {
  {
    rule_id: "navigation-landmark-name-missing",
    message: "This page has multiple navigation landmarks, and this one has no static distinguishing name.",
    suggestion: "Add a non-empty aria-label, aria-labelledby reference, or title that distinguishes this navigation landmark.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn duplicate_navigation_landmark_name_finding(
  node : @dom.Node,
  path : String,
) -> Finding {
  {
    rule_id: "navigation-landmark-name-duplicate",
    message: "This navigation landmark repeats a static name used by an earlier navigation landmark.",
    suggestion: "Give same-type navigation landmarks distinct names when users need to tell them apart.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn abstract_role_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "aria-abstract-role",
    message: "This role attribute contains an abstract ARIA role token.",
    suggestion: "Use a concrete ARIA role or remove the abstract role token.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn aria_hidden_focus_review_item(node : @dom.Node, path : String) -> ReviewItem {
  let tabindex_reason = match node.attrs().get("tabindex") {
    Some(Some(value)) if value.trim() == "-1" =>
      "This aria-hidden subtree contains tabindex=\"-1\". Programmatic focus and CSS/runtime state require browser review."
    _ =>
      "This aria-hidden subtree contains a potentially focusable element. CSS and runtime focus state require browser review."
  }
  {
    rule_id: "aria-hidden-focus-review",
    reason: tabindex_reason,
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn navigation_landmark_name_review_item(
  node : @dom.Node,
  path : String,
) -> ReviewItem {
  {
    rule_id: "navigation-landmark-name-missing",
    reason: "This navigation landmark may derive a name from SVG or runtime content, which static HTML cannot determine reliably.",
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
fn missing_button_name_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "button-name-missing",
    message: "This button has no recognizable accessible name.",
    suggestion: "Add visible button text, a non-empty value or alt attribute as appropriate, aria-label, aria-labelledby, or title.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn implicit_submit_button_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "button-implicit-submit",
    message: "This button inside a form has no explicit type and therefore defaults to submit.",
    suggestion: "Set type=\"button\" for a non-submit action or type=\"submit\" when submission is intended.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn skipped_heading_level_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "heading-level-skipped",
    message: "建议检查标题层级：this heading skips one or more levels from the preceding heading.",
    suggestion: "Review whether this heading level should follow the preceding native heading.",
    element_path: path,
    line: node.origin_line(),
    column: node.origin_col(),
  }
}

///|
fn missing_heading_name_finding(node : @dom.Node, path : String) -> Finding {
  {
    rule_id: "heading-name-missing",
    message: "This heading has no recognizable accessible name.",
    suggestion: "Add heading text, an image with non-empty alt text, aria-label, or aria-labelledby.",
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

///|
fn child_path(parent_path : String, name : String, occurrence : Int) -> String {
  if parent_path == "" {
    "\{name}:nth-of-type(\{occurrence})"
  } else {
    "\{parent_path} > \{name}:nth-of-type(\{occurrence})"
  }
}
