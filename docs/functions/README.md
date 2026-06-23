# Function Reference

Reference documentation for the public functions exported by the core `ZeroFailed` module. These pages
are generated from the source with [PlatyPS](https://github.com/PowerShell/platyPS) and committed as the
source of truth for the prose.

| Function                                                                            | Description                                                                                    |
|-------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| [Copy-FolderFromGitRepo](./Copy-FolderFromGitRepo.md)                               | Shallow-clones a git repository and copies a named subfolder to a destination.                 |
| [Get-ExtensionAvailableTasks](./Get-ExtensionAvailableTasks.md)                     | Discovers the InvokeBuild task names defined by an extension.                                  |
| [Get-ExtensionDependencies](./Get-ExtensionDependencies.md)                         | Resolves an extension's declared dependencies from its module manifest.                        |
| [Get-ExtensionFromGitRepository](./Get-ExtensionFromGitRepository.md)               | Installs a git-hosted extension if it is not already present locally.                          |
| [Get-ExtensionFromPowerShellRepository](./Get-ExtensionFromPowerShellRepository.md) | Installs a PowerShell-repository-hosted extension if it is not already present locally.        |
| [Get-FunctionsFileListFromExtension](./Get-FunctionsFileListFromExtension.md)       | Lists the function files provided by an extension.                                             |
| [Get-InstalledExtensionDetails](./Get-InstalledExtensionDetails.md)                 | Determines whether an extension is already installed locally and returns its path and version. |
| [Get-TasksFileListFromExtension](./Get-TasksFileListFromExtension.md)               | Lists the task definition files provided by an extension.                                      |
| [Register-ExtensionAndDependencies](./Register-ExtensionAndDependencies.md)         | Resolves, installs and registers a single extension and its dependencies.                      |
| [Register-Extensions](./Register-Extensions.md)                                     | Top-level entry point that registers all configured extensions and their dependencies.         |
| [Resolve-ExtensionDuplicates](./Resolve-ExtensionDuplicates.md)                     | De-duplicates resolved extensions by name, warning only on genuine version conflicts.          |
| [Resolve-ExtensionMetadata](./Resolve-ExtensionMetadata.md)                         | Normalises the supported extension configuration syntaxes into a canonical metadata hashtable. |
