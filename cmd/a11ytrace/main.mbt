///|
enum OutputFormat {
  Text
  Json
  DetailedJson
} derive(Eq)

///|
struct CliConfig {
  path : String
  format : OutputFormat
  rule_ids : Array[String]?
}

///|
enum CliPlan {
  Help
  Audit(CliConfig)
  ArgumentError(String)
}

///|
#coverage.skip
async fn main {
  let all_args = @env.args()
  let args = if all_args.is_empty() { all_args[:] } else { all_args[1:] }
  match parse_cli_args(args) {
    Help => write_stdout(usage_text())
    ArgumentError(message) =>
      write_stderr("error: \{message}\n\n\{usage_text()}")
    Audit(config) => run_audit(config)
  }
}

///|
async fn run_audit(config : CliConfig) -> Unit {
  let html = @fs.read_file(config.path).text() catch {
    error => {
      write_stderr("error: could not read \{config.path}: \{error}\n")
      return
    }
  }
  if config.format is DetailedJson {
    run_detailed_audit(html, config.rule_ids)
    return
  }
  let result = match config.rule_ids {
    None => @a11ytrace_lib.audit_html(html)
    Some(rule_ids) =>
      match @a11ytrace_lib.audit_html_with_rules(html, rule_ids) {
        Audited(result) => result
        ConfigurationError(UnknownRuleId(rule_id)) => {
          write_stderr("error: unknown A11yTrace rule ID: \{rule_id}\n")
          return
        }
      }
  }
  match config.format {
    Json => write_stdout(@a11ytrace_lib.render_audit_json(result) + "\n")
    Text => write_stdout(render_text(result))
    DetailedJson => ()
  }
}

///|
async fn run_detailed_audit(html : String, rule_ids : Array[String]?) -> Unit {
  let result = match rule_ids {
    None => @a11ytrace_lib.audit_html_detailed(html)
    Some(ids) =>
      match @a11ytrace_lib.audit_html_detailed_with_rules(html, ids) {
        Audited(result) => result
        ConfigurationError(UnknownRuleId(rule_id)) => {
          write_stderr("error: unknown A11yTrace rule ID: \{rule_id}\n")
          return
        }
      }
  }
  write_stdout(@a11ytrace_lib.render_detailed_audit_json(result) + "\n")
}

///|
fn parse_cli_args(args : ArrayView[String]) -> CliPlan {
  let mut path : String? = None
  let mut format = Text
  let mut format_supplied = false
  let mut rule_ids : Array[String]? = None
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--help" | "-h" => return Help
      "--format" => {
        if index + 1 >= args.length() {
          return ArgumentError("--format requires text, json, or detailed-json")
        }
        if format_supplied {
          return ArgumentError("--format may be provided only once")
        }
        match args[index + 1] {
          "text" => format = Text
          "json" => format = Json
          "detailed-json" => format = DetailedJson
          value => return ArgumentError("unsupported format: \{value}")
        }
        format_supplied = true
        index += 1
      }
      "--rules" => {
        if index + 1 >= args.length() {
          return ArgumentError("--rules requires a comma-separated list")
        }
        if rule_ids is Some(_) {
          return ArgumentError("--rules may be provided only once")
        }
        rule_ids = Some(split_rule_ids(args[index + 1]))
        index += 1
      }
      argument if argument.has_prefix("-") =>
        return ArgumentError("unknown option: \{argument}")
      argument =>
        match path {
          None => path = Some(argument)
          Some(_) => return ArgumentError("only one HTML file may be provided")
        }
    }
    index += 1
  }
  match path {
    Some(path) => Audit({ path, format, rule_ids, })
    None => ArgumentError("an HTML file is required")
  }
}

///|
fn split_rule_ids(value : String) -> Array[String] {
  let rule_ids = []
  for part in value.split(",") {
    let rule_id = part.trim()
    if !rule_id.is_empty() {
      rule_ids.push(rule_id.to_owned())
    }
  }
  rule_ids
}

///|
fn render_text(result : @a11ytrace_lib.AuditResult) -> String {
  let output = StringBuilder()
  match result {
    Findings(findings) => {
      output.write_string("Audit findings:\n")
      append_findings(output, findings)
    }
    FindingsWithParseErrors(findings, diagnostics) => {
      output.write_string("Audit findings with parser diagnostics:\n")
      append_findings(output, findings)
      append_diagnostics(output, diagnostics)
    }
    ParseErrors(diagnostics) => {
      output.write_string("Parser errors prevented an audit:\n")
      append_diagnostics(output, diagnostics)
    }
  }
  output.to_string()
}

///|
fn append_findings(
  output : StringBuilder,
  findings : Array[@a11ytrace_lib.Finding],
) -> Unit {
  if findings.is_empty() {
    output.write_string("  No findings from the selected static checks.\n")
    return
  }
  for finding in findings {
    output.write_string("  [\{finding.rule_id}] \{finding.element_path}")
    append_location(output, finding.line, finding.column)
    output.write_string(": \{finding.message}\n")
  }
}

///|
fn append_diagnostics(
  output : StringBuilder,
  diagnostics : Array[@a11ytrace_lib.ParseDiagnostic],
) -> Unit {
  if diagnostics.is_empty() {
    return
  }
  output.write_string("Parser diagnostics:\n")
  for diagnostic in diagnostics {
    output.write_string("  [\{diagnostic.code}]")
    append_location(output, diagnostic.line, diagnostic.column)
    output.write_string(": \{diagnostic.message}\n")
  }
}

///|
fn append_location(output : StringBuilder, line : Int?, column : Int?) -> Unit {
  match (line, column) {
    (Some(line), Some(column)) =>
      output.write_string(" (line \{line}, column \{column})")
    _ => output.write_string(" (location unavailable)")
  }
}

///|
fn usage_text() -> String {
  (
    #|Usage: a11ytrace <file.html> [--format text|json|detailed-json] [--rules id1,id2]
    #|
    #|Audit one local HTML file with A11yTrace.
    #|
    #|Options:
    #|  -h, --help              Show this help text.
    #|  --format text|json|detailed-json
    #|                          Output text (default), compatible JSON, or detailed JSON with review items.
    #|  --rules id1,id2         Run only these rule IDs; an empty value runs no rules.
  ).to_string()
}

///|
#coverage.skip
async fn write_stdout(text : String) -> Unit {
  @stdio.stdout.write(text) catch {
    _ => ()
  }
}

///|
#coverage.skip
async fn write_stderr(text : String) -> Unit {
  @stdio.stderr.write(text) catch {
    _ => ()
  }
}
