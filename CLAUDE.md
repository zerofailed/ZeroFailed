# ZeroFailed

Extensible automation framework for reliable automated processes, built on the
[InvokeBuild](https://github.com/nightroman/Invoke-Build) PowerShell module. PowerShell 7+ Core only, cross-platform.
This repo is the **core `ZeroFailed` module** — it resolves, downloads and loads *extensions* (separate PS modules, e.g.
`ZeroFailed.Build.DotNet`) that a consumer references in its `.zf/config.ps1`.

## Style guides (read first)

Authoritative conventions live in `.knowledge-base/powershell/`:
- `powershell-coding-guidance.md` — function/naming/formatting rules.
- `powershell-pester-testing-guidance.md` — test structure and patterns.

## Build & Test

- `./build.ps1` — full build (`FullBuild`: Init, Version, Build, **Test**, Analysis, TestReport, Package). Bootstraps
  InvokeBuild, imports the local module, then runs `.zf/config.ps1`.
- `./build.ps1 -Tasks Test` — run just the test stage. Useful params: `-Configuration Debug|Release`,
  `-LogLevel minimal|normal|detailed`.
- The build *process* is not in this repo — it comes from the `ZeroFailed.Build.PowerShell` /
  `ZeroFailed.Build.Common` extensions, downloaded into `.zf/extensions/` (gitignored) on first build.
- Run a single test file directly (fast inner loop): `Invoke-Pester -Path module/functions/<Name>.Tests.ps1`.
- Tests use **Pester 5.7.1** (pinned in `.zf/config.ps1`); coverage is measured over `module/functions`.

## Module layout & loading

- `module/ZeroFailed.psd1` (manifest, requires PS 7.0) + `module/ZeroFailed.psm1` (loader). The loader dot-sources every
  `module/functions/*.ps1` (excluding `*.Tests.ps1`) and exports only functions **not** prefixed with `_`.
- `module/import-tasks.ps1` (aliased `ZeroFailed.tasks`) is the extension-loading entrypoint: reads `$zerofailedExtensions`
  (or the `ZF_EXTENSIONS` env JSON, which takes precedence), registers + de-dupes extensions, then loads their `tasks/`
  and `functions/`.
- One public function per file in `module/functions/`, each with a sibling `<Name>.Tests.ps1`. Private functions are
  `_`-prefixed (e.g. `_resolveModuleNameFromPath.ps1`) and not exported.
- `module/ZeroFailed.module.tests.ps1` enforces conventions per function: copyright header, `[CmdletBinding()]`, `param`,
  and an existing sibling test. Opt a function out of the cmdletbinding/param check with a `#SUPPRESS-ParameterChecks`
  comment.

## Conventions

- Every `.ps1` / `.Tests.ps1` starts with the Endjin copyright header:
  `# <copyright file="<filename>" company="Endjin Limited">` ... `# </copyright>`.
- Functions: approved Verb-Noun names (`Get-Verb`), `[CmdletBinding()]`, typed `param()`, `[OutputType(...)]`. Model
  function: `module/functions/Get-ExtensionDependencies.ps1`.
- Tests: `BeforeAll` dot-sources the SUT via `$PSCommandPath.Replace('.Tests.ps1','.ps1')` and explicitly dot-sources any
  in-module deps. `TestDrive:` for filesystem fixtures; `Should -Invoke` for behaviour. Model test:
  `module/functions/Get-ExtensionDependencies.Tests.ps1`.

## Docs

- `docs/functions/*.md` are **generated, committed PlatyPS Markdown** (one per public function), regenerated/scaffolded by
  `./build.ps1` (settings `$PSMarkdownDocs*` in `.zf/config.ps1`). Fill in real Synopsis/Description/Examples in the `.md`
  and commit them — that Markdown is the source of truth for the prose, **do not** include comment-based help in the `.ps1`.

## Gotchas

- `.zf/config.ps1` is the build's control panel: extension list, `$PesterVersion`, `$PesterCodeCoveragePaths`,
  doc/publish settings, and `task . FullBuild`.
- Don't commit generated/ignored artefacts: `PesterTestResults.xml`, `_codeCoverage/`, `_packages/`, `.zf/extensions/`.
- `examples/basic/` shows how a downstream repo consumes the framework (`build.ps1` + `.zf/config.ps1`).
