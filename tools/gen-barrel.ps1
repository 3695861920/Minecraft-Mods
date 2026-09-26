$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

# The barrel uses TerraFirmaCraft's own barrel art instead of vanilla's barrel textures.
# TFC's barrel model is a 12x16x12 cylinder made of wood planks, an iron hoop band and an inner "sheet",
# with per-wood-type children. We copy the geometry and one wood's textures into our own namespace so that
# nothing references "tfc:" at runtime (TFC is not a dependency of this port).
# Pure ASCII script: all non-ASCII text lives in UTF-8 data files.

# Locate the project root without hardcoding where this machine keeps it: these scripts live in <root>/tools, so
# the root is this script's own parent folder and the TFC jar is expected there. The previous version globbed an
# absolute path, which meant the generators could only run on one machine - and could not run in CI at all, where
# the release workflow downloads the jar into exactly this root.
$root = Split-Path $PSScriptRoot -Parent
$tfcJarFile = Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $tfcJarFile) { throw ('no TerraFirmaCraft jar in ' + $root + ': these generators read TFC textures and data out of it') }
$tfcJar = (Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File | Select-Object -First 1).FullName
$ns = 'tfc_food_port'
$assets = Join-Path $root "src\main\resources\assets\$ns"
$data = Join-Path $root "src\main\resources\data\$ns"
$utf8 = New-Object System.Text.UTF8Encoding($false)

function New-Dir([string]$path) { if (-not (Test-Path $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null } }

$z = [System.IO.Compression.ZipFile]::OpenRead($tfcJar)

# ---------------------------------------------------------------- textures
# oak planks + oak sheet + the hoop band; the same three inputs TFC's own barrel model uses
$copies = @{
  'assets/tfc/textures/block/barrel_hoop.png'            = 'textures\block\barrel_hoop.png'
  'assets/tfc/textures/block/wood/planks/oak.png'        = 'textures\block\barrel_planks.png'
  'assets/tfc/textures/block/wood/sheet/oak.png'         = 'textures\block\barrel_sheet.png'
}
foreach ($src in $copies.Keys) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $src } | Select-Object -First 1
  if (-not $e) { throw ("missing in the TFC jar: " + $src) }
  $out = Join-Path $assets $copies[$src]
  New-Dir (Split-Path $out -Parent)
  [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $out, $true)
  Write-Output ('texture  <- ' + $src)
}

# ---------------------------------------------------------------- block model
# Take TFC's geometry verbatim and swap its texture declarations for ours.
$modelEntry = $z.Entries | Where-Object { $_.FullName -eq 'assets/tfc/models/block/barrel.json' } | Select-Object -First 1
if (-not $modelEntry) { throw 'missing assets/tfc/models/block/barrel.json in the TFC jar' }
$sr = New-Object System.IO.StreamReader($modelEntry.Open())
$geometry = $sr.ReadToEnd()
$sr.Close()

$myTextures = '"parent":"minecraft:block/block","textures":{' +
  '"particle":"' + $ns + ':block/barrel_planks",' +
  '"planks":"' + $ns + ':block/barrel_planks",' +
  '"sheet":"' + $ns + ':block/barrel_sheet",' +
  '"hoop":"' + $ns + ':block/barrel_hoop"}'
$model = [regex]::Replace($geometry, '"parent"\s*:\s*"[^"]*"\s*,\s*"textures"\s*:\s*\{[^}]*\}', $myTextures)

# guard: the geometry must still reference the texture variables we just defined, and must not mention tfc:
if ($model -notmatch [regex]::Escape($ns + ':block/barrel_planks')) { throw ('model lost its textures: ' + $model) }
if ($model -match '"tfc:') { throw ('model still references the tfc namespace: ' + $model) }
if ($model -notmatch '#planks' -or $model -notmatch '#hoop') { throw 'model geometry was not carried over' }

New-Dir (Join-Path $assets 'models\block')
[System.IO.File]::WriteAllText((Join-Path $assets 'models\block\barrel.json'), $model, $utf8)
Write-Output 'model    -> models/block/barrel.json (TFC geometry, own textures)'

# NOTE: every interpolated id below MUST use ${ns}: - writing "$ns:" makes PowerShell parse it as a scope qualifier
# and silently expand to nothing, producing ids like "/block/barrel".
$blockstate = "{`n  `"variants`": {`n    `"`": {`n      `"model`": `"${ns}:block/barrel`"`n    }`n  }`n}`n"
if ($blockstate -notmatch [regex]::Escape($ns + ':block/barrel')) { throw ('blockstate lost its namespace: ' + $blockstate) }
[System.IO.File]::WriteAllText((Join-Path $assets 'blockstates\barrel.json'), $blockstate, $utf8)
Write-Output 'state    -> blockstates/barrel.json'

$itemModel = "{`n  `"parent`": `"${ns}:block/barrel`"`n}`n"
if ($itemModel -notmatch [regex]::Escape($ns + ':block/barrel')) { throw ('item model lost its namespace: ' + $itemModel) }
[System.IO.File]::WriteAllText((Join-Path $assets 'models\item\barrel.json'), $itemModel, $utf8)
Write-Output 'item     -> models/item/barrel.json'

$z.Dispose()

# ---------------------------------------------------------------- loot table
# copy_components moves the barrel's fluid component from the block entity onto the dropped item,
# so breaking a filled barrel keeps its contents.
$loot = @"
{
  "type": "minecraft:block",
  "pools": [
    {
      "bonus_rolls": 0.0,
      "rolls": 1.0,
      "conditions": [
        {
          "condition": "minecraft:survives_explosion"
        }
      ],
      "entries": [
        {
          "type": "minecraft:item",
          "name": "$ns`:barrel",
          "functions": [
            {
              "function": "minecraft:copy_components",
              "source": "block_entity",
              "include": [
                "$ns`:barrel_fluid"
              ]
            }
          ]
        }
      ]
    }
  ],
  "random_sequence": "$ns`:blocks/barrel"
}
"@
if ($loot -notmatch [regex]::Escape($ns + ':barrel')) { throw ('loot lost its namespace: ' + $loot) }
New-Dir (Join-Path $data 'loot_table\blocks')
[System.IO.File]::WriteAllText((Join-Path $data 'loot_table\blocks\barrel.json'), $loot, $utf8)
Write-Output 'loot     -> loot_table/blocks/barrel.json (copy_components)'
