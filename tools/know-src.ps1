# Dump a class (or grep inside it) from the 1.21.1 reference sources.
#
# Why this exists: porting between Minecraft versions is decided by exact signatures, and reading them out of a jar
# is the only way to be sure. Guessing a signature costs a full Gradle compile round trip (minutes) and produces a
# misleading error, so the source of truth is always this: the decompiled Minecraft, and the NeoForge sources jar.
#
#   tools/know-src.ps1 -Class net/minecraft/world/item/BlockItem.java -Contains 'getCloneItemStack'
#   tools/know-src.ps1 -Class net/neoforged/neoforge/registries/DeferredRegister.java -Contains 'registerBlock'
#
# Pure ASCII on purpose: PowerShell 5.1 reads non-BOM files as the system ANSI code page.

param(
    [Parameter(Mandatory = $true)][string]$Class,
    [string]$Contains = '',
    [int]$Context = 6,
    [string]$Platform = 'mc'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$cache = Join-Path $env:USERPROFILE '.gradle\caches'

$jars = if ($Platform -eq 'neoforge') {
    Get-ChildItem -Path (Join-Path $cache 'modules-2\files-2.1\net.neoforged\neoforge') -Recurse -Filter '*-sources.jar' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '21\.1' }
}
else {
    Get-ChildItem -Path (Join-Path $cache 'neoformruntime\intermediate_results') -Filter '*_output.jar' -ErrorAction SilentlyContinue
}

if (-not $jars) { Write-Error "no reference jar found for platform '$Platform'"; exit 1 }

# The decompile cache holds several candidate jars; the one carrying sources is the one that actually has the entry.
foreach ($jar in $jars)
{
    $zip = $null

    try
    {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName)
        $entry = $zip.Entries | Where-Object { $_.FullName -eq $Class -or $_.FullName -eq ($Class -replace '/', '\') }

        if (-not $entry) { continue }

        $reader = New-Object System.IO.StreamReader($entry.Open())
        $lines = @()

        while (-not $reader.EndOfStream) { $lines += $reader.ReadLine() }

        $reader.Close()
        Write-Output ("# {0}  ({1} lines)  from {2}" -f $Class, $lines.Count, $jar.Name)

        if (-not $Contains)
        {
            $lines
            break
        }

        $hits = 0

        for ($i = 0; $i -lt $lines.Count; $i++)
        {
            if ($lines[$i] -notmatch [regex]::Escape($Contains)) { continue }

            $hits++
            $from = [Math]::Max(0, $i - $Context)
            $to = [Math]::Min($lines.Count - 1, $i + $Context)
            Write-Output ("--- line {0} ---" -f ($i + 1))

            for ($j = $from; $j -le $to; $j++) { Write-Output $lines[$j] }
        }

        if ($hits -eq 0) { Write-Output ("# no line matched '{0}'" -f $Contains) }
        break
    }
    finally
    {
        if ($zip) { $zip.Dispose() }
    }
}
