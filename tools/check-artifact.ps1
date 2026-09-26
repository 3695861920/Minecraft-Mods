$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Downloads the published release asset and checks that it really is the mod.
#
# A green workflow only says the build step exited zero. This opens the jar and looks for the things that make it a
# working mod rather than an empty archive: the mod metadata, our classes, the recipe files with their conditions,
# and the generated textures. Pure ASCII.

$repo = '3695861920/Minecraft-Mods'
$headers = @{ 'User-Agent' = 'tfc-food-port-check'; 'Accept' = 'application/vnd.github+json' }
$work = Join-Path $PSScriptRoot 'out\release-check'
New-Item -ItemType Directory -Force -Path $work | Out-Null

$rels = Invoke-RestMethod -Uri ("https://api.github.com/repos/" + $repo + "/releases") -Headers $headers -TimeoutSec 30
$rel = $rels[0]
Write-Output ('release: ' + $rel.tag_name + '   published ' + $rel.published_at + '   draft=' + $rel.draft)
Write-Output ('body length: ' + $rel.body.Length + ' chars of release notes')

$asset = $rel.assets | Where-Object { $_.name -like '*.jar' } | Select-Object -First 1
Write-Output ('asset: ' + $asset.name + '   ' + [Math]::Round($asset.size / 1KB) + ' KB   downloads=' + $asset.download_count)

$jar = Join-Path $work $asset.name
Invoke-WebRequest -Uri $asset.browser_download_url -Headers @{ 'User-Agent' = 'tfc-food-port-check' } -OutFile $jar -TimeoutSec 180
$localSize = (Get-Item $jar).Length
Write-Output ('downloaded ' + [Math]::Round($localSize / 1KB) + ' KB')

$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
try {
    $names = $z.Entries | ForEach-Object { $_.FullName }
    $find = { param($pattern) ($names | Where-Object { $_ -match $pattern } | Measure-Object).Count }

    Write-Output ''
    Write-Output '=== contents ==='
    Write-Output ('mod metadata      : ' + (& $find 'META-INF/neoforge\.mods\.toml'))
    Write-Output ('our classes       : ' + (& $find '^com/tfc_food_port/.*\.class$'))
    Write-Output ('recipes           : ' + (& $find '^data/tfc_food_port/recipe/.*\.json$'))
    Write-Output ('loot tables       : ' + (& $find '^data/tfc_food_port/loot_table/.*\.json$'))
    Write-Output ('item definitions  : ' + (& $find '^assets/tfc_food_port/items/.*\.json$'))
    Write-Output ('item textures     : ' + (& $find '^assets/tfc_food_port/textures/item/.*\.png$'))
    Write-Output ('block textures    : ' + (& $find '^assets/tfc_food_port/textures/block/.*\.png$'))
    Write-Output ('mooncake textures : ' + (& $find '^assets/tfc_food_port/textures/item/food/mooncake/'))
    Write-Output ('raw mooncakes     : ' + (& $find '^assets/tfc_food_port/textures/item/food/raw_mooncake/'))
    Write-Output ('banana bunch      : ' + (& $find 'banana_bunch_stage'))
    Write-Output ('banana leaves tex : ' + (& $find 'block/plant/banana_leaves\.png'))

    # the metadata should carry the optional dependencies and the licence
    $meta = $z.Entries | Where-Object { $_.FullName -eq 'META-INF/neoforge.mods.toml' } | Select-Object -First 1
    $sr = New-Object System.IO.StreamReader($meta.Open())
    $toml = $sr.ReadToEnd()
    $sr.Close()
    Write-Output ''
    Write-Output '=== mods.toml checks ==='
    foreach ($needle in @('modId = "tfc_food_port"', 'license = "EUPL-1.2"', 'modId = "farmersdelight"', 'type = "optional"', 'modId = "kaleidoscope_cookery"')) {
        Write-Output ('  ' + ($(if ($toml.Contains($needle)) { 'OK  ' } else { 'MISS' }) + ' ' + $needle))
    }

    # and a sample recipe should still carry its condition
    $sample = $z.Entries | Where-Object { $_.FullName -eq 'data/tfc_food_port/recipe/food/jam/strawberry.json' } | Select-Object -First 1
    if ($sample) {
        $sr2 = New-Object System.IO.StreamReader($sample.Open())
        $jam = $sr2.ReadToEnd()
        $sr2.Close()
        Write-Output ('  ' + ($(if ($jam -match 'neoforge:conditions' -and $jam -match 'farmersdelight') { 'OK  ' } else { 'MISS' }) + ' strawberry jam carries its mod_loaded condition'))
    } else {
        Write-Output '  MISS strawberry jam recipe not present'
    }
}
finally {
    $z.Dispose()
}
