# Generated primary-language subtag data

`language_subtags.mbt` is generated project data for the two static language
tag checks. It contains **8275 unique** IANA registry records whose `Type` is
`language`, packed as a delimiter-bounded lowercase lookup string. It is not a
runtime dependency and no library API performs a network request.

## Source and update record

- Source: [IANA Language Subtag Registry](https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry)
- Registry `File-Date`: **2026-09-17**
- Generated: **2026-09-30**
- Method: run `tools/generate_language_subtags.ps1` against a downloaded copy
  of the registry; extract records with `Type: language`, extract their
  `Subtag`, lowercase, sort, deduplicate, then emit `language_subtags.mbt`.

For a deliberate update, download the current registry outside the repository
and run, from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File tools/generate_language_subtags.ps1 `
  -RegistryPath C:\path\to\language-subtag-registry.txt `
  -OutputPath language_subtags.mbt
```

Review the changed `File-Date`, count, generated diff, and IANA's current
registry terms before committing an update. The repository does not copy the
raw registry or IANA source code; it retains only this derived list and source
attribution. The generator and A11yTrace's checking code are original project
code under the repository's Apache-2.0 license.

## Check semantics

The data answers one narrow question: whether the first non-empty, hyphen-
separated primary subtag is registered as `Type: language`. The checks also
reject obvious separator/character failures (empty subtags, leading/trailing
hyphen, or non-alphanumeric subtags). They deliberately do **not** impose the
stricter complete BCP 47 grammar on later subtags. Therefore `zh-Hans`,
`fr-CH`, `en-US-GB`, and `de-hello` are accepted when their primary subtag is
known; an unknown primary such as `em-US`, an ISO-639.2-only `eng`, a
grandfathered form beginning with an unregistered primary, or `en--US` is
reported.

This is based on the “known primary language subtag” approach in the W3C ACT
rules [HTML page lang attribute has valid language tag](https://www.w3.org/WAI/standards-guidelines/act/rules/html-page-lang-valid-bf051a/)
and [Element with lang attribute has valid language tag](https://www.w3.org/WAI/standards-guidelines/act/rules/de46e4/).
It does not determine the actual language of page text, the applicable
top-level browsing context, CSS visibility, the flat tree, inherited text, or
exceptions for names, technical terms, and vernacular words.
