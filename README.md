# ZeroFailed

Provides an extensibility framework for automated processes implemented using the [InvokeBuild](https://github.com/nightroman/Invoke-Build) PowerShell module.  For more details on why you might
want to design your automated processes around InvokeBuild, please refer to its [wiki](https://github.com/nightroman/Invoke-Build/wiki/Concepts).

For example, a software build script can use this module to:

- Bootstrap itself using 2 files:
    - A boilerplate entrypoint script that installs the top-level dependencies:
        - `InvokeBuild`
        - `ZeroFailed`
    - A configuration script, by convention stored in `.zf/config.ps1`, that defines:
        - One or more `ZeroFailed` extension modules that implement functionality needed for the process (and optionally, the process itself)
        - Configuration to drive those extensions for this specific process
        - InvokeBuild task definitions for custom functionality specific to this process

Examples of these files can be found [here](./examples/).

## Extensions

Extensions are PowerShell modules that follow the conventions below to offer specific features to ZeroFailed processes that consume them.

- Shared functions are defined in a `functions` directory
- Shared InvokeBuild tasks are defined in a `tasks` directory
- OPTIONAL: Dependencies on other extensions are defined in a `dependencies.psd1` file
- OPTIONAL: 1 or more InvokeBuild process definitions - currently these can reside anywhere within the module, with the onus being on the consumer to know where

For example:
```
<module-root>/
├── functions/
│   ├── functionA.ps1
│   └── functionB.ps1
├── tasks/
│   ├── tasksGroupA.tasks.ps1       (a .tasks.ps1 file may contain 1 or more task definitions)
│   ├── tasksGroupB.tasks.ps1
│   ├── bigTask.tasks.ps1           (a complex task may be defined in a dedicated code file)
│   └── someProcess.build.ps1
├── dependencies.psd1               (defines any other extensions this one depends on)
├── MyExtension.psd1
└── MyExtension.psm1
```

### Using Extensions

A ZeroFailed-based process can use extensions by referencing them via the `zerofailedExtensions` property in its `.zf/config.ps1` file.

#### Simple Syntax

This uses the simplest syntax to reference the latest stable versions of 2 extensions available via PowerShell Gallery.

```
$zerofailedExtensions = @(
    "ZeroFailed.Build.DotNet"
    "ZeroFailed.Build.Containers"
)
```

#### Advanced Syntax

This uses the richer syntax to reference specific versions of 2 public extensions and an internal extension available via a private repository.

```
$zerofailedExtensions = @(
    @{
        Name = "ZeroFailed.Build.DotNet"
        Version = "1.5.0"
    }
    @{
        Name = "ZeroFailed.Build.Containers"
        Version = "1.3.0"
    }
    @{
        Name = "MyCustomExtension"
        Repository = "MyPrivatePSRepository"
    }
)
```

#### Syntax for local development testing

This shows how to reference an extension available via a local file path, which can be useful when testing or debugging your own extensions.

```
$zerofailedExtensions = @(
    @{
        Name = "MyCustomExtension"
        Path = "~/MyCustomExtension/module/MyCustomExtension.psd1"
    }
)
```


## ZeroFailed Process Overview

The diagram below provides an overview of how a ZeroFailed-based process interacts with the extensibility framework when it is executed.

![Extensibility Overview](./docs/assets/extensibility.png)