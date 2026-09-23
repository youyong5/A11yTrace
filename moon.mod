// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "youyong5/a11ytrace"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/youyong5/A11yTrace"

license = "Apache-2.0"

keywords = [ "accessibility", "a11y", "html", "lint" ]

preferred_target = "wasm"

description = "Pure HTML accessibility checks for MoonBit projects."

import {
  "bobzhang/html_parser@0.1.8",
  "moonbitlang/async@0.19.0",
}
