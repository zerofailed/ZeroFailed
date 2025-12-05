---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 12/04/2025
PlatyPS schema version: 2024-05-01
title: Register-Extensions
---

# Register-Extensions

## SYNOPSIS

Validates and registers a set of extensions and their dependencies.

## SYNTAX

### __AllParameterSets

```
Register-Extensions [-ExtensionsConfig] <hashtable[]> [-DefaultPSRepository] <string>
 [-ZfPath] <string> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function validates, installs (if necessary) and registers the specified set of ZeroFailed extensions and any dependencies
they declare, returning a fully-populated set of metadata for all extensions.

If an extension is considered valid and available, then it will be marked as enabled; otherwise it will be marked as disabled.

## EXAMPLES

### EXAMPLE 1

$extensionsConfig = @(
    @{
        Name = "PublicExtension"                            # Extension available via PS Gallery, latest stable version
    }
    @{
        Name = "PinnedPublicExtension"                      # Extension available via PS Gallery, specific version
        Version = "1.0.2"
    }
    @{
        Name = "BetaPublicExtension"                        # Extension available via PS Gallery, latest pre-release version
        PreRelease = $true
    }
    @{
        Name = "PublicExtension"                            # Extension available via a Git repo, using the 'main' branch
        GitRepository = "https://github.com/myorg/PublicExtension"
    }
    @{
        Name = "PublicExtension"                            # Extension available via a Git repo, using a tagged version
        GitRepository = "https://github.com/myorg/PublicExtension"
        GitRef = "refs/tags/1.0.0"
    }
    @{
        Name = "PublicExtension"                            # Extension available via a Git repo, using a custom branch
        GitRepository = "https://github.com/myorg/PublicExtension"
        GitRef = "feature/new-stuff"
    }
    @{
        Name = "PublicExtension"                            # Extension available via a Git repo, using the 'main' branch, located in a non-standard folder
        GitRepository = "https://github.com/myorg/PublicExtension"
        GitRepositoryPath = "src/PublicExtension"
    }
    @{
        Path = "~/myLocalExtension/module"                  # Extension being developed locally
    }
    @{
        Path = "/myNonExistantExtension/module"             # Incorrect path to a local extension
    }
)
PS:> Register-Extensions -ExtensionsConfig $extensionsConfig -DefaultRepository PSGallery -ZfPath "/myproject/.zf"

@(
    @{
        Name = "PublicExtension"                            # Extension available via PS Gallery, latest stable version
        Version = "1.5.2"
        Path = "/myproject/.zf/extensions/PublicExtension/1.5.2"
        Enabled = $true
    }
    @{
        Name = "PinnedPublicExtension"                      # Extension available via PS Gallery, specific version
        Version = "1.0.2"
        Path = "/myproject/.zf/extensions/PinnedPublicExtension/1.0.2"
        Enabled = $true
    }
    @{
        Name = "BetaPublicExtension"                        # Extension available via PS Gallery, latest pre-release version
        Version = "2.0.0-beta0010"
        Path = "/myproject/.zf/extensions/BetaPublicExtension/2.0.0"
        Enabled = $true
    }
    @{
        Name = "PublicExtension"                            # Extension available via a Git repo, using the 'main' branch
        Version = "main"
        Path = "/myproject/.zf/extensions/PublicExtension/main"
        Enabled = $true
    }
    @{
        Name = "PublicExtension"                            # Extension available via a Git repo, using a tagged version
        Version = "refs/tags/1.0.0"
        Path = "/myproject/.zf/extensions/PublicExtension/refs-tags-1.0.0"
        Enabled = $true
    }
    @{
        Name = "PublicExtension"                            # Extension available via a Git repo, using a custom branch
        Version = "feature/new-stuff"
        Path = "/myproject/.zf/extensions/PublicExtension/feature-new-stuff"
        Enabled = $true
    }
    @{
        Name = "PublicExtension"                            # Extension available via a Git repo, using the 'main' branch, located in a non-standard folder
        Version = "main"
        Path = "/myproject/.zf/extensions/PublicExtension/main"
        Enabled = $true
    }
    @{
        Name = "myLocalExtension"                           # Extension being developed locally
        Path = "/myLocalExtension/module"
        Enabled = $true
    }
    @{
        Name = "myNonExistantExtension"
        Path = "/myNonExistantExtension/module"   # Incorrect path to a local extension
        Enabled = $false
    }
)

## PARAMETERS

### -DefaultPSRepository

The default PowerShell repository to use when installing those types of extensions. Defaults to 'PSGallery'.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ExtensionsConfig

An array of extension configuration objects.

```yaml
Type: System.Collections.Hashtable[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ZfPath

The path to the '.zf' storage directory (e.g.
where extensions will be installed).

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Collections.Hashtable

Returns an array of fully-populated extension metadata.

## NOTES

## RELATED LINKS

- []()
