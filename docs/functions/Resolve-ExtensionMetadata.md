---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 12/04/2025
PlatyPS schema version: 2024-05-01
title: Resolve-ExtensionMetadata
---

# Resolve-ExtensionMetadata

## SYNOPSIS

Resolves extension metadata from a string or hashtable configuration.

## SYNTAX

### __AllParameterSets

```
Resolve-ExtensionMetadata [-Value] <Object> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function resolves extension metadata from a string or hashtable configuration.
The function supports both simple and object-based syntax.

## EXAMPLES

### EXAMPLE 1

Resolve-ExtensionMetadata -Value "MyExtension"
@{
    Name = "MyExtension"
}

### EXAMPLE 2

Resolve-ExtensionMetadata -Value "c:\path\to\MyExtension"
@{
    Name = "MyExtension"
    Path = "c:\path\to\MyExtension"
}

### EXAMPLE 3

Resolve-ExtensionMetadata -Value @{Path="c:\path\to\MyExtension"}
@{
    Name = "MyExtension"
    Path = "c:\path\to\MyExtension"
}

### EXAMPLE 4

Resolve-ExtensionMetadata -Value @{NAme="MyExtension"; Version="1.0.0"}
@{
    Name = "MyExtension"
    Version = "1.0.0"
}

## PARAMETERS

### -Value

The extension configuration to resolve.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Collections.Hashtable

Returns a hashtable containing the extension metadata in canonical form

## NOTES

## RELATED LINKS

- []()
