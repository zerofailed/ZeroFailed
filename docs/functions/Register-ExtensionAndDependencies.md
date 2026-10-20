---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 10/20/2026
PlatyPS schema version: 2024-05-01
title: Register-ExtensionAndDependencies
---

# Register-ExtensionAndDependencies

## SYNOPSIS

Registers an extension and its dependencies.

## SYNTAX

### __AllParameterSets

```
Register-ExtensionAndDependencies [-ExtensionConfig] <Object> [-TargetPath] <string>
 [[-RequiredBy] <string>] [[-LockedExtensions] <IDictionary>] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

A recursive function responsible for registering the specified extension and its dependencies.

A local extension whose path does not exist is not registered: a warning is written, and nothing is returned for it.

Each extension's metadata includes a 'LockEntry' that records how it was requested and resolved: its source, the requested git reference or version, the commit or version that was installed, and which extension required it.

An extension can request a 'MinimumVersion' instead of a 'Version' or 'GitRef'.
It is installed at the newest release from that version up to, but not including, the next major version: a module version from a PowerShell repository, or a git tag named after a semantic version (for example, '1.4.2' or 'v1.4.2').
An installed release in that range is used as it is.
Its lock entry records the range (for example, '[1.4.0,2.0.0)') as the requested version and, for a git repository, the release tag as 'resolvedRef'.

When locked extensions are provided, an extension whose lock entry matches how it is requested is installed at the commit or version recorded in the lock entry.
For a 'MinimumVersion', the lock entry matches when it has the same source and its version is in the range, whatever range it records as requested.
Before any of the extension's code runs, an error is thrown if its content differs from the lock entry.
The tasks of an extension that does not match its lock entry are not found, so its code does not run before the difference is reported.

## EXAMPLES

### EXAMPLE 1

$extensionConfig = @{
    Name = "MyExtension"
    Path = "C:\Extensions\MyExtension"
    Repository = "https://example.com/extensions"
}
PS:>Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath "$PWD/.zf/extensions"

## PARAMETERS

### -ExtensionConfig

A hashtable containing the initial extension metadata provided by the user.
This parameter is mandatory.

```yaml
Type: System.Object
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

### -LockedExtensions

The extensions recorded in the extensions lock file, keyed by name.
When omitted, extensions are resolved without using a lock file.

```yaml
Type: System.Collections.IDictionary
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -RequiredBy

The name of the extension that declared this extension as a dependency.
Omit this for an extension that is configured directly.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TargetPath

The path to the folder where ZeroFailed extensions are installed (typically '.zf/extensions').
This parameter is mandatory.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Collections.Hashtable

The function returns an array of hashtables representing the processed extension metadata for the input extension and its dependencies.

## NOTES

## RELATED LINKS

- []()
