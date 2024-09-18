# endjin-devops

Provides an extensibility framework for automated processes implemented using the [InvokeBuild](https://github.com/nightroman/Invoke-Build) PowerShell module.  For more details on why you might
want to design your automated processes around InvokeBuild, please refer to its [wiki](https://github.com/nightroman/Invoke-Build/wiki/Concepts).

For example, a software build script can use this module to:

- Bootstrap itself using 2 files:
    - A boilerplate entrypoint script that installs the top-level dependencies:
        - `InvokeBuild`
        - `endjin-devops`
    - A configuration script, by convention stored in `.devops/config.ps1`, that defines:
        - One or more `endjin-devops` extension modules that implement functionality needed for the process (and optionally, the process itself)
        - Configuration to drive those extensions for this specific process
        - InvokeBuild task definitions for custom functionality specific to this process

Examples of these files can be found [here](./examples/).

## TODO: Documentation Topics:
- Extensions
    - How they are structured
    - How to consume
    - Dependency management
- Default process

## Extensions

Extensions are PowerShell modules that follow the conventions below to offer specific features to endjin-devops processes that consume them.

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
├── dependencies.psd1
├── MyExtension.psd1
└── MyExtension.psm1
```

The diagram below provides an overview of how the automated process interacts with the extensibility framework & InvokeBuild when it is executed.

![Extensibility Overview](./docs/assets/extensibility.png)