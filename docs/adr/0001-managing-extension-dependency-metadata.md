# Managing extension dependency metadata 

## Status

* Status: decided
* Deciders: endjineers
* Date: June 2025

## Context and Problem Statement

The initial version ZeroFailed relied on extensions including the file `dependencies.psd1` with the details of any other extensions they depended on.  When being used on more complex scenarios a [bug](https://github.com/zerofailed/ZeroFailed/issues/5) was found when an extension tried to declare multiple dependencies.  Whilst the `Import-PowerShellDataFile` cmdlet will load a `.psd1` file containing an array of hashtables (as opposed to its intended format of a single hashtable), it will only return the first hashtable item.

Therefore a new approach is required for how extensions declare their dependencies.

## Decision Drivers

* Must support declaring multiple dependencies
* Backwards-compatibility considerations
* Use of custom files vs. leveraging existing PowerShell module infrastructure

## Considered Options

* Option 1: Change the structure of the existing `dependencies.psd1` file
* Option 2: Store dependency metadata as PowerShell module [PrivateData](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.psmoduleinfo.privatedata)

## Decision Outcome

Implement Option 2.

### Positive Consequences

* Fixes the original bug
* Aligns with existing PowerShell tooling & conventions
* Does not preclude use of additional metadata in the future

### Negative Consequences

* To avoid a breaking change the ZeroFailed module will need to support both approaches, at least in the short-term
* Existing extensions will need to be updated to align with this new approach

## Pros and Cons of the Options

### Change the structure of the existing `dependencies.psd1` file

This is the file's existing structure, that exhibits the issue outlined above:
```
@(
    @{
        Name = "Extension_A"
    }
    @{
        Name = "Extension_B"
        Version = "1.2.3"
    }
    @{
        Name = "Extension_B"
        GitRepository = "https://github.com/myOrg/Extension_C"
        GitRef = "main"
    }
)
```

This option involves changing the expected structure of the `dependencies.psd1` file to be as follows:
```
@{
    dependencies = @(
        @{
            Name = "Extension_A"
        }
        @{
            Name = "Extension_B"
            Version = "1.2.3"
        }
        @{
            Name = "Extension_B"
            GitRepository = "https://github.com/myOrg/Extension_C"
            GitRef = "main"
        }
    )
}
```

* Good, because it requires minimal changes to the core ZeroFailed module
* Good, because backwards-compatibility can be retained without having to support 2 completely different approaches
* Bad, since all extensions will ultimately need to be updated to adopt this new convention
* Bad, arguably using a custom file creates clutter in the extensions

### Store dependency metadata as PowerShell module PrivateData

This involves adding a 'ZeroFailed' key to the `PrivateData` part of the module manifest, as illustrated below:
```
@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ZeroFailed.psm1'

    ...

    PrivateData = @{

        PSData = @{
            
            ...

        }
        ZeroFailed = @{
            Dependencies = @(
                @{
                    Name = "Extension_A"
                }
                @{
                    Name = "Extension_B"
                    Version = "1.2.3"
                }
                @{
                    Name = "Extension_B"
                    GitRepository = "https://github.com/myOrg/Extension_C"
                    GitRef = "main"
                }
            )
        }
    }
}
```

* Good, arguably a more elegant solution to maintain the dependency details as part of the PowerShell module metadata
* Good, it provides a more future-proof and generic facility to store ZeroFailed-related metadata
* Bad, because backwards-compatibility can only be retained by supporting (at least temporarily) 2 different approaches for determining dependencies
* Bad, since all extensions will ultimately need to be updated to adopt this new convention
