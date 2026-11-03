# <copyright file="_getExtensionContentHash.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest

    # Creates a folder containing files with exact content, from a hashtable of relative path => content
    function newFolder([hashtable] $Files) {
        $folder = Join-Path $TestDrive "$(New-Guid)"
        foreach ($relativePath in $Files.Keys) {
            $path = Join-Path $folder $relativePath
            New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
            $content = $Files[$relativePath]
            if ($content -is [byte[]]) {
                [IO.File]::WriteAllBytes($path, $content)
            }
            else {
                [IO.File]::WriteAllText($path, $content)
            }
        }
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        return $folder
    }

    # Creates a link to a folder: a junction on Windows (which needs no extra rights), otherwise a symbolic link. The links
    # are recorded, so that they can be removed before the test drive is, as its clean-up follows a link that loops.
    $script:folderLinks = [System.Collections.Generic.List[string]]::new()
    function newFolderLink([string] $Path, [string] $Target) {
        New-Item -ItemType ($IsWindows ? 'Junction' : 'SymbolicLink') -Path $Path -Target $Target | Out-Null
        $script:folderLinks.Add($Path)
    }

    function getSha256([byte[]] $Bytes) {
        [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
    }
}

Describe '_getExtensionContentHash' {

    It 'Hashes a manifest of each file''s relative path and content hash' {
        $folder = newFolder @{ 'a.txt' = "x`n"; 'sub/b.txt' = "y`n" }
        $manifest = "a.txt`0$(getSha256 ([Text.Encoding]::UTF8.GetBytes("x`n")))`n" +
                    "sub/b.txt`0$(getSha256 ([Text.Encoding]::UTF8.GetBytes("y`n")))`n"

        $result = _getExtensionContentHash -Path $folder

        $result | Should -Be "sha256:$(getSha256 ([Text.Encoding]::UTF8.GetBytes($manifest)))"
    }

    It 'Returns the same hash for the same content in different folders' {
        $folder1 = newFolder @{ 'a.txt' = "x`n"; 'tasks/b.ps1' = "y`n" }
        $folder2 = newFolder @{ 'tasks/b.ps1' = "y`n"; 'a.txt' = "x`n" }

        _getExtensionContentHash -Path $folder1 | Should -Be (_getExtensionContentHash -Path $folder2)
    }

    It 'Returns a different hash when <Description>' -ForEach @(
        @{ Description = 'a file''s content differs'; Files = @{ 'a.txt' = "changed`n"; 'tasks/b.ps1' = "y`n" } }
        @{ Description = 'a file has been renamed'; Files = @{ 'renamed.txt' = "x`n"; 'tasks/b.ps1' = "y`n" } }
        @{ Description = 'a file has been moved'; Files = @{ 'a.txt' = "x`n"; 'functions/b.ps1' = "y`n" } }
        @{ Description = 'a file has been added'; Files = @{ 'a.txt' = "x`n"; 'tasks/b.ps1' = "y`n"; 'c.txt' = '' } }
    ) {
        $original = newFolder @{ 'a.txt' = "x`n"; 'tasks/b.ps1' = "y`n" }
        $changed = newFolder $Files

        _getExtensionContentHash -Path $changed | Should -Not -Be (_getExtensionContentHash -Path $original)
    }

    Context 'A linked folder' {
        BeforeEach {
            $linkedFolder = newFolder @{ 'b.ps1' = "y`n" }
            $folder = newFolder @{ 'a.txt' = "x`n" }
            newFolderLink -Path (Join-Path $folder 'tasks') -Target $linkedFolder
        }

        AfterEach {
            # Removing a link does not remove the folder that it links to
            foreach ($link in $script:folderLinks) {
                Remove-Item -LiteralPath $link -Force
            }
            $script:folderLinks.Clear()
        }

        It 'Includes the files in the linked folder, as if they were in the extension' {
            $expected = newFolder @{ 'a.txt' = "x`n"; 'tasks/b.ps1' = "y`n" }

            _getExtensionContentHash -Path $folder | Should -Be (_getExtensionContentHash -Path $expected)
        }

        It 'Returns a different hash when a file in the linked folder changes' {
            $original = _getExtensionContentHash -Path $folder

            [IO.File]::WriteAllText((Join-Path $linkedFolder 'b.ps1'), "changed`n")

            _getExtensionContentHash -Path $folder | Should -Not -Be $original
        }

        It 'Includes the files in a folder that links to itself only once' {
            newFolderLink -Path (Join-Path $linkedFolder 'loop') -Target $linkedFolder
            $expected = newFolder @{ 'a.txt' = "x`n"; 'tasks/b.ps1' = "y`n" }

            _getExtensionContentHash -Path $folder | Should -Be (_getExtensionContentHash -Path $expected)
        }
    }

    It 'Ignores the line endings of text files' {
        $lf = newFolder @{ 'a.ps1' = "line1`nline2`n" }
        $crlf = newFolder @{ 'a.ps1' = "line1`r`nline2`r`n" }

        _getExtensionContentHash -Path $crlf | Should -Be (_getExtensionContentHash -Path $lf)
    }

    It 'Does not change the line endings of binary files' {
        $lf = newFolder @{ 'a.dll' = [byte[]](0, 1, 10, 2) }
        $crlf = newFolder @{ 'a.dll' = [byte[]](0, 1, 13, 10, 2) }

        _getExtensionContentHash -Path $crlf | Should -Not -Be (_getExtensionContentHash -Path $lf)
    }

    It 'Ignores files that are written when an extension is installed' {
        $plain = newFolder @{ 'a.txt' = "x`n" }
        $installed = newFolder @{ 'a.txt' = "x`n"; 'PSGetModuleInfo.xml' = '<installed />'; '.zf-source.json' = '{}' }

        _getExtensionContentHash -Path $installed | Should -Be (_getExtensionContentHash -Path $plain)
    }

    It 'Includes files with the same names as the ignored files when they are in a sub-folder' {
        $plain = newFolder @{ 'a.txt' = "x`n" }
        $nested = newFolder @{ 'a.txt' = "x`n"; 'sub/PSGetModuleInfo.xml' = '<data />' }

        _getExtensionContentHash -Path $nested | Should -Not -Be (_getExtensionContentHash -Path $plain)
    }

    It 'Supports PowerShell drive paths' {
        $folder = newFolder @{ 'a.txt' = "x`n" }
        $drivePath = Join-Path 'TestDrive:' (Split-Path -Leaf $folder)

        _getExtensionContentHash -Path $drivePath | Should -Be (_getExtensionContentHash -Path $folder)
    }
}
