param(
    [Parameter(Mandatory = $true)][string]$Prefix,
    [Parameter(Mandatory = $true)][string]$Out
)

$ErrorActionPreference = 'Stop'

# Downloads the NeoForge sources jar for a given Minecraft version, so the port can be written against the real API
# instead of against memory. The 26.1.2 port was done this way and the sources were what made it possible.
#
# It asks the maven for the list of published versions and picks the newest one that starts with the requested
# prefix, rather than hardcoding a version that will age badly.
# Pure ASCII.

$meta = 'https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml'
Write-Output ("looking for versions starting with '" + $Prefix + "' at " + $meta)

$xml = & curl.exe -fsSL --max-time 60 $meta
if ($LASTEXITCODE -ne 0) { throw ('could not read the maven metadata (curl exit ' + $LASTEXITCODE + ')') }

$versions = [regex]::Matches($xml, '<version>([^<]+)</version>') | ForEach-Object { $_.Groups[1].Value }
$matching = $versions | Where-Object { $_ -like ($Prefix + '*') } | Sort-Object { [version]($_ -replace '-.*$', '') }
if (-not $matching) {
    Write-Output ('no published version starts with ' + $Prefix + '. Available families:')
    $versions | ForEach-Object { ($_ -replace '\..*$', '') } | Sort-Object -Unique | ForEach-Object { Write-Output ('  ' + $_) }
    throw 'no matching NeoForge version'
}

$pick = $matching[-1]
Write-Output ('using NeoForge ' + $pick + '   (' + $matching.Count + ' candidates)')

$base = 'https://maven.neoforged.net/releases/net/neoforged/neoforge/' + $pick
$jarName = 'neoforge-' + $pick + '-sources.jar'
$url = $base + '/' + $jarName

New-Item -ItemType Directory -Force -Path (Split-Path $Out -Parent) | Out-Null
Write-Output ('downloading ' + $url)
& curl.exe -fsSL --max-time 300 -o $Out $url
if ($LASTEXITCODE -ne 0) { throw ('download failed (curl exit ' + $LASTEXITCODE + ')') }

Write-Output ('saved ' + $Out + '   ' + [Math]::Round((Get-Item $Out).Length / 1MB, 1) + ' MB')
Write-Output ('extract with: Expand-Archive ' + $Out + ' -DestinationPath <dir>')
