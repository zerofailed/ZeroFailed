# Resolving the extensions that are used, their processes, and their import order

## Status

* Status: proposed
* Deciders: endjineers
* Date: November 2026

## Context and Problem Statement

An extension can be referenced more than once: by several entries in the configuration, as a dependency of several extensions, or at more than one version. ZeroFailed registers every reference, then has to decide:

* which version of each extension is used, and which extensions are used at all
* which process each extension declares, when its references disagree
* which extension's process runs
* the order in which the tasks and functions of the extensions are imported

ZeroFailed 2.0.1 made these decisions in several places, each inferring facts from the metadata of a reference. For example, it treated a reference without a lock entry as one from the configuration, but an explicitly disabled dependency has no lock entry either. Each place that inferred a fact differently produced an edge case (see [#17](https://github.com/zerofailed/ZeroFailed/pull/17)). This record states the rules, so that a change, or a reported edge case, can be checked against them.

## Decision Drivers

* The configuration is what the user controls, so it should decide when references disagree
* A version of an extension that is not used must not affect the extensions that are used
* A Write run and a Frozen run of the same configuration and lock file must give the same result
* Each rule should be decided in one place, from facts that are recorded rather than inferred

## Definitions

* **Reference (occurrence)**: each time an extension is registered. Every entry in the configuration registers one, and so does every dependency that an extension declares, unless a local extension in the configuration is used in its place.
* **Registration order**: the order of the configuration, with each extension followed by its dependencies (depth first).
* **Configured reference**: the reference that an entry in the configuration registered. `Register-Extensions` records these when it registers them. Whether a reference has a lock entry, or whether its lock entry is marked `direct`, does not decide this.
* **Chosen version**: the first reference to each extension once the versions are reconciled. With a `MinimumVersion`, the version must be in every range, and a version in the configuration is used wherever it is listed. Otherwise, the first one registered is used.
* **Used extension**: an extension in the configuration, or one that the chosen version of a used, enabled extension requires.
* **Disabled reference**, which has one of 3 causes:
  * Explicitly disabled (`Enabled = $false`): it is not installed or imported, and has no lock entry. Its `Process` is ignored.
  * A local extension whose path does not exist: it is not registered, so another reference to the same extension can be used.
  * In a Frozen run, a reference that does not match the lock file: it is not installed. If it is the chosen version, the run fails. Otherwise, its `Process` still counts, as the extension that declares it is used.

## Decision Outcome

### Which extensions are used

`_resolveUsedExtensions` starts from the configured references and follows the dependencies of the chosen version of each used, enabled extension. It keeps the chosen version, the configured references, and the references that a used extension declares. It removes every other reference, so a dependency that only an unused version requires is not imported or locked. It is still installed, because extensions are installed as they are registered.

### Which process an extension declares

`_resolveUsedExtensions` is the only place that chooses the `Process` of an extension. It uses, in order:

1. the first `Process` in a configured reference, in the order of the configuration, including a configured reference that version reconciliation discarded
2. otherwise, the first `Process` that a used extension declares for it, in registration order, including a declaration that is not kept (for example, a dependency that a local extension is used in place of)

A warning names any other process. A disabled chosen version is given no process. The `Process` of every other reference that is kept is removed, so that `Resolve-ExtensionDuplicates` does not choose a different one. Version reconciliation does not copy processes.

### Which process runs

`import-tasks.ps1` runs the process of the first enabled extension, in registration order, that declares one. A warning names the others.

### Import order

`Get-ExtensionImportOrder` imports every extension after the extensions that it requires, including a dependency that several extensions share. Otherwise, an extension listed earlier is imported later, so when 2 extensions define the same task or property, the one listed first is used. Extensions that require each other in a circle are imported together, latest first, when the latest of them would be.

### Considered options for process precedence

* **Strict registration order**: the first reference to declare a `Process` wins, whatever its kind. A configured reference listed after an extension that declares the same extension's process would lose to it.
* **Configuration first (chosen)**: a `Process` in the configuration wins, then registration order. This lets the user override a process without reordering the configuration.

### Positive Consequences

* Each rule is decided in one place, from recorded facts
* A Write run and a Frozen run choose the same process
* A reported edge case can be checked against these rules, rather than fixed in isolation

### Negative Consequences

* Within one extension, a `Process` in the configuration takes precedence, but between different extensions, registration order decides which process runs. The README describes both rules.
* An unused version's dependencies are still installed, although they are not imported or locked
* A configuration that lists the same extension more than once with conflicting settings is resolved by these rules, with a warning, but is not otherwise supported
