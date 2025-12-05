---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 12/04/2025
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
 [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

A recursive function responsible for registering the specified extension and its dependencies.

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
