# <copyright file="_mergeExtensionProcess.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _mergeExtensionProcess {
    <#
        .SYNOPSIS
        Copies the process definition of an extension reference that is not used to the one that is used.

        .DESCRIPTION
        An extension that is referenced more than once (for example, a dependency of 2 extensions, or a dependency that the
        configuration overrides) is used from one reference only.
        The 'Process' that a discarded reference declares is still needed, so it is copied to the reference that is used
        when that reference does not declare one.
        A warning is written when both references declare a different 'Process', and the one that is used keeps its own.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param (
        # The extension reference that is used
        [Parameter(Mandatory)]
        [hashtable] $Extension,

        # An extension reference with the same name that is not used
        [Parameter(Mandatory)]
        [hashtable] $Duplicate
    )

    if (!$Duplicate.ContainsKey('Process') -or [string]::IsNullOrEmpty($Duplicate.Process)) {
        return
    }

    if (!$Extension.ContainsKey('Process') -or [string]::IsNullOrEmpty($Extension.Process)) {
        Write-Verbose "Using process '$($Duplicate.Process)' for extension '$($Extension.Name)', from another reference to it"
        $Extension.Process = $Duplicate.Process
    }
    elseif ($Extension.Process -ne $Duplicate.Process) {
        Write-Warning ("Extension '$($Extension.Name)' is referenced with different process definitions - " +
                       "using '$($Extension.Process)' and ignoring '$($Duplicate.Process)'")
    }
}
