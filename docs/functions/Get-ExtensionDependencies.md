---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 12/04/2025
PlatyPS schema version: 2024-05-01
title: Get-ExtensionDependencies
---

# Get-ExtensionDependencies

## SYNOPSIS

Retrieves the dependencies of a given extension by reading its module manifest.

## SYNTAX

### __AllParameterSets

```
Get-ExtensionDependencies [-Extension] <hashtable> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Retrieves the dependencies of a given extension by reading its module manifest and falling-back to
the legacy definition method in a `dependencies.psd1` file.

## EXAMPLES

### EXAMPLE 1

Get-ExtensionDependencies -Extension $extension
@{
    Name = "some-dependency"
    Version = "1.0.0"
}

## PARAMETERS

### -Extension

The metadata object for the extension we are resolving dependencies for.

```yaml
Type: System.Collections.Hashtable
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Collections.Hashtable

Returns the resolved extension metadata for each dependency of the specified extension.

## NOTES

By convention an extension must declare its dependencies in its module manifest under the 'PrivateData'
key.
The dependencies can be specified in one of two formats:

Short-hand syntax:
    PrivateData = @{
        ZeroFailed = @{
            ExtensionDependencies = @(
                'ExtensionA'
            )
        }
    }

Full syntax:
    PrivateData = @{
        ZeroFailed = @{
            ExtensionDependencies = @(
                @{
                    Name = 'ExtensionA'
                    Version = '1.0.0'
                }
                @{
                    Name = 'MyExtension'
                    GitRepository = 'https://github.com/myorg/myextension
                    GitRef = 'main'
                }
            )
        }
    }

Mixed syntax:
    PrivateData = @{
        ZeroFailed = @{
            ExtensionDependencies = @(
                'ExtensionA'
                @{
                    Name = 'ExtensionB'
                    Version = '2.0.0'
                }
            )
        }
    }

## RELATED LINKS

- []()
