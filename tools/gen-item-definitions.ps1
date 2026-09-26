$ErrorActionPreference = 'Stop'

# Since MC 1.21.4 (and therefore 26.1.2) an item needs THREE things to render:
#   1. assets/<ns>/items/<item path>.json    <- the item model definition, points at a model
#   2. assets/<ns>/models/item/<name>.json   <- the model itself
#   3. assets/<ns>/textures/item/<name>.png  <- the texture the model uses
# Without (1) every item falls back to the missing model, which is what a client shows as the
# checkerboard/purple "error" texture.
#
# The item model definition layer, assets/<ns>/items/**, exists only from MC 1.21.4 onwards.
#
# On a target without it an item resolves its model straight from models/item/**, and these files are simply not
# read. So the whole script is a no-op there rather than writing 210 files that do nothing - the files would be
# harmless but they would show up in every asset count and audit as if they mattered.
#
# Note that the layer is not merely absent from 1.21.1: the older versions would ALSO reject the model files that
# point at it. Leaving the model tree to gen-resources.ps1 and this script to the define layer keeps the two from
# getting tangled.
#
# This mirrors the models/item tree into items/, so the two can never drift apart.
# Pure ASCII script.

# Locate the project root without hardcoding where this machine keeps it: these scripts live in <root>/tools, so
# the root is this script's own parent folder and the TFC jar is expected there. The previous version globbed an
# absolute path, which meant the generators could only run on one machine - and could not run in CI at all, where
# the release workflow downloads the jar into exactly this root.
$root = Split-Path $PSScriptRoot -Parent
$tfcJarFile = Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $tfcJarFile) { throw ('no TerraFirmaCraft jar in ' + $root + ': these generators read TFC textures and data out of it') }

# Resources are written into the selected target's module rather than into the repository root. See tools/targets.ps1.
. (Join-Path $PSScriptRoot 'targets.ps1')
$moduleDir = Get-ModuleDir $root
$caps = Get-ModuleCaps
$assets = Join-Path $moduleDir 'src\main\resources\assets\tfc_food_port'
$modelDir = Join-Path $assets 'models\item'
$defDir = Join-Path $assets 'items'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$ns = 'tfc_food_port'

if (-not $caps.itemDefinitions) {
  # Clear a stale layer if this target ever had one, so switching targets cannot leave files behind that the game
  # ignores but a reader would take for real.
  if (Test-Path $defDir) { Remove-Item $defDir -Recurse -Force; Write-Output 'removed a stale items/ definition layer' }
  Write-Output ('target ' + (Get-TargetName) + ' has no item definition layer: nothing to write')
  return
}

if (Test-Path $defDir) { Remove-Item $defDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $defDir | Out-Null

$created = 0
$models = Get-ChildItem $modelDir -Recurse -File -Filter *.json
foreach ($m in $models) {
  # model path relative to models/item, e.g. "food/jam/blackberry" or "plant/blackberry_bush"
  $rel = $m.FullName.Substring($modelDir.Length + 1) -replace '\\', '/' -replace '\.json$', ''

  $def = @"
{
  "model": {
    "type": "minecraft:model",
    "model": "${ns}:item/$rel"
  }
}
"@
  # Guard against the PowerShell interpolation trap: inside a double-quoted string "$ns:" is parsed as a
  # scope/drive qualifier and silently expands to nothing, which produced "model": "/food/cheese" and made
  # every item render as the missing model. Always write "${ns}:".
  if ($def -notmatch [regex]::Escape($ns + ':item/')) {
    throw ("generated definition for '$rel' lost its namespace: " + $def)
  }
  $out = Join-Path $defDir ($rel -replace '/', '\')
  Write-TextFile ($out + '.json') $def
  $created++
}

Write-Output ("item model definitions written: " + $created + "  (from " + $models.Count + " models)")

# ---- the leaf items, whose icons are block models ----
# A tree fruit's leaves are a real item (shears and Silk Touch take them), and its icon points at the leaf BLOCK
# model rather than at a flat sprite, which is exactly how vanilla shows an oak leaves item. They cannot be derived
# from models/item, so they are emitted here instead - this is the one script that owns assets/<ns>/items/, and
# letting any other script write into it means this one's directory wipe would silently delete them.
#
# The list comes from the block models on disk rather than a hardcoded fruit list, so adding a fruit cannot leave a
# leaf item behind.
$leafModels = Get-ChildItem (Join-Path $assets 'models\block\plant') -File -Filter '*_leaves.json' |
  ForEach-Object { $_.BaseName }
foreach ($leaf in $leafModels) {
  $leafDef = "{`n  `"model`": {`n    `"type`": `"minecraft:model`",`n    `"model`": `"${ns}:block/plant/$leaf`"`n  }`n}`n"
  if ($leafDef -notmatch [regex]::Escape($ns + ':block/plant/')) { throw ("leaf definition for '$leaf' lost its namespace") }
  $leafOut = Join-Path $defDir ("plant\$leaf.json")
  $leafDir = Split-Path $leafOut -Parent
  if (-not (Test-Path $leafDir)) { New-Item -ItemType Directory -Force -Path $leafDir | Out-Null }
  [System.IO.File]::WriteAllText($leafOut, $leafDef, $utf8)
}
Write-Output ("leaf item definitions written: " + $leafModels.Count + "  (icons use the leaf block model)")

# ---- report the trees side by side so a mismatch would be obvious ----
$defs = Get-ChildItem $defDir -Recurse -File -Filter *.json | ForEach-Object {
  $_.FullName.Substring($defDir.Length + 1) -replace '\\', '/' -replace '\.json$', ''
}
$modelNames = $models | ForEach-Object { $_.FullName.Substring($modelDir.Length + 1) -replace '\\', '/' -replace '\.json$', '' }
$onlyModel = $modelNames | Where-Object { $defs -notcontains $_ }
# A leaf item's definition points at a BLOCK model on purpose, so it has no models/item entry to pair with. Those
# are excluded from the report rather than reported forever as a mismatch.
$leafNames = $leafModels | ForEach-Object { 'plant/' + $_ }
$onlyDef = $defs | Where-Object { ($modelNames -notcontains $_) -and ($leafNames -notcontains $_) }
Write-Output ("models without a definition: " + $onlyModel.Count)
$onlyModel | ForEach-Object { Write-Output ('  ! ' + $_) }
Write-Output ("definitions without a model: " + $onlyDef.Count + "  (the " + $leafNames.Count + " leaf items use block models)")
$onlyDef | ForEach-Object { Write-Output ('  ! ' + $_) }
Write-Output ("definitions on disk        : " + $defs.Count)
