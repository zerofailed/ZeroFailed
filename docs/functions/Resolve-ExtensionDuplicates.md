---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-US
Module Name: ZeroFailed
ms.date: 11/17/2026
PlatyPS schema version: 2024-05-01
title: Resolve-ExtensionDuplicates
---

# Resolve-ExtensionDuplicates

## SYNOPSIS

Removes duplicate extension references, keeping the first one found.

## SYNTAX

### __AllParameterSets

```
Resolve-ExtensionDuplicates [-Extensions] <hashtable[]> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

It is common for a low-level extension to be referenced by more than one higher-level
extension (e.g.
as a shared dependency).
When the resolved extension list contains
multiple references to the same extension 'Name', this function removes the duplicates,
keeping the first one found.

The extensions are returned in the order that they were given, so that the depth-first
resolution order is preserved.
This order decides which extension's process definition is used.
Get-ExtensionImportOrder uses it to decide the order in which the tasks and functions of
the extensions are imported.

When the reference that is kept does not declare a 'Process', but a removed reference to
the same extension does, the kept reference uses that 'Process'.
A warning is logged when the references declare different processes.

A warning is only logged when the duplicate references resolve to genuinely different
versions.
The reliable indicator of the resolved version across all extension types
(Git, PowerShell repository and local path) is the 'Path' property, which encodes the
version or git ref as part of the on-disk folder structure.
Duplicates that resolve to
the same 'Path' are the same version and are de-duplicated silently.

## EXAMPLES

### EXAMPLE 1

$deduplicated = Resolve-ExtensionDuplicates -Extensions $resolvedExtensions
Removes duplicate references from the resolved extension list (keeping the first one found),
warning only where the duplicates resolve to genuinely different versions.

## PARAMETERS

### -Extensions

The array of resolved extensions (as returned by Register-Extensions) to de-duplicate.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Collections.Hashtable

Returns the de-duplicated array of extensions, preserving the original resolution order (the first
reference to each extension 'Name' is kept).

## NOTES

## RELATED LINKS

- []()
