param(
    [Parameter(Mandatory = $true)][string]$A,
    [Parameter(Mandatory = $true)][string]$B,
    [int]$Limit = 25
)

$ErrorActionPreference = 'Stop'

# Compares two jars entry by entry: which entries were added, removed, or changed in content.
#
# The manifest and the mod metadata are deliberately included rather than skipped, because a release that differs
# only in those two files is still a different release.
#
# NOTE: param() has to be the first statement in a PowerShell script. Putting a comment or $ErrorActionPreference
# above it makes PowerShell treat 'param' as a command name and fail with "param is not recognized". This file had
# exactly that bug for one run.
#
# Pure ASCII.

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-Entries([string]$path) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($path)
    $map = @{}

    try {
        foreach ($e in $zip.Entries) {
            $reader = New-Object System.IO.StreamReader($e.Open())
            $text = $reader.ReadToEnd()
            $reader.Close()

            $hash = [System.BitConverter]::ToString(
                (New-Object System.Security.Cryptography.SHA256Managed).ComputeHash(
                    [System.Text.Encoding]::UTF8.GetBytes($text))).Replace('-', '').ToLower()

            $map[$e.FullName] = @{ Size = $e.Length; Hash = $hash }
        }
    }
    finally { $zip.Dispose() }

    return $map
}

$ea = Get-Entries $A
$eb = Get-Entries $B

Write-Output ("A: " + (Split-Path $A -Leaf) + "  " + $ea.Count + " entries")
Write-Output ("B: " + (Split-Path $B -Leaf) + "  " + $eb.Count + " entries")
Write-Output ""

$added = @($eb.Keys | Where-Object { -not $ea.ContainsKey($_) } | Sort-Object)
$removed = @($ea.Keys | Where-Object { -not $eb.ContainsKey($_) } | Sort-Object)
$changed = @($ea.Keys | Where-Object { $eb.ContainsKey($_) -and $ea[$_].Hash -ne $eb[$_].Hash } | Sort-Object)

Write-Output ("only in A (removed): " + $added.Count)
Write-Output ("only in B (added)  : " + $removed.Count)
Write-Output ("different content  : " + $changed.Count)
Write-Output ""

# Group the changed entries by extension, which is what tells line endings apart from a real content change: a line
# ending change hits every text file in a directory, while a real change hits a handful of related files.
Write-Output "changed entries by extension:"
$changed | ForEach-Object { [System.IO.Path]::GetExtension($_) } | Group-Object | Sort-Object Count -Descending |
    Select-Object -First 10 | ForEach-Object { Write-Output ("  " + $_.Name + "  " + $_.Count) }
Write-Output ""

Write-Output ("first " + $Limit + " changed entries, with byte deltas:")
$changed | Select-Object -First $Limit | ForEach-Object {
    $d = $eb[$_].Size - $ea[$_].Size
    Write-Output ("  " + ("{0,8}" -f $d) + "  " + $_)
}

if ($added.Count -gt 0) { Write-Output ""; Write-Output "added sample:"; $added | Select-Object -First $Limit | ForEach-Object { Write-Output ("  " + $_) } }
if ($removed.Count -gt 0) { Write-Output ""; Write-Output "removed sample:"; $removed | Select-Object -First $Limit | ForEach-Object { Write-Output ("  " + $_) } }
