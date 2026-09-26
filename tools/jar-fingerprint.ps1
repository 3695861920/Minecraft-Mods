param(
    [string]$Jar,
    [string]$Out
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Prints a fingerprint of the built mod jar: every entry's path, size and CRC, plus a combined hash.
#
# Used to prove that a refactor changed nothing. A mod jar is not byte reproducible - zip entries carry timestamps -
# so comparing the file itself would report spurious differences. The set of entries and their contents is what
# actually matters, and that is what this records.
# Pure ASCII.

if (-not $Jar) {
    $jars = Get-ChildItem -Path (Join-Path $PSScriptRoot '..') -Recurse -File -Filter 'tfc_food_port-*.jar' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match 'build[\\/]libs' -and $_.Name -notmatch 'sources' }
    if (-not $jars) { throw 'no built jar found' }
    $Jar = ($jars | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
$Jar = (Resolve-Path $Jar).Path
Write-Output ('jar: ' + $Jar + '   ' + [Math]::Round((Get-Item $Jar).Length / 1KB) + ' KB')

$z = [System.IO.Compression.ZipFile]::OpenRead($Jar)
$lines = New-Object System.Collections.Generic.List[string]
foreach ($e in ($z.Entries | Sort-Object FullName)) {
    # Directory entries have no content and are not interesting
    if ($e.FullName.EndsWith('/')) { continue }
    $lines.Add(('{0}|{1}|{2}' -f $e.FullName, $e.Length, $e.Crc32))
}
$z.Dispose()

Write-Output ('entries: ' + $lines.Count)

# A stable digest over the sorted fingerprint: this is the number that has to match after a refactor.
$sha = [System.Security.Cryptography.SHA256]::Create()
$bytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
$hash = ($sha.ComputeHash($bytes) | ForEach-Object { '{0:x2}' -f $_ }) -join ''
Write-Output ('fingerprint: ' + $hash)

if ($Out) {
    [System.IO.File]::WriteAllLines($Out, $lines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output ('written: ' + $Out)
}
