$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Web.Extensions

# Locate the project root without hardcoding where this machine keeps it: these scripts live in <root>/tools, so
# the root is this script's own parent folder and the TFC jar is expected there. The previous version globbed an
# absolute path, which meant the generators could only run on one machine - and could not run in CI at all, where
# the release workflow downloads the jar into exactly this root.
$root = Split-Path $PSScriptRoot -Parent
$tfcJarFile = Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $tfcJarFile) { throw ('no TerraFirmaCraft jar in ' + $root + ': these generators read TFC textures and data out of it') }

# The audit checks the selected target's module rather than the repository root. See tools/targets.ps1.
. (Join-Path $PSScriptRoot 'targets.ps1')
$moduleDir = Get-ModuleDir $root
$res  = Join-Path $moduleDir 'src\main\resources'
$assets = Join-Path $res 'assets\tfc_food_port'
$data   = Join-Path $res 'data\tfc_food_port'
$parser = New-Object System.Web.Script.Serialization.JavaScriptSerializer

# ---- 1. every blockstate model target exists ----
$modelMissing = 0
Get-ChildItem (Join-Path $assets 'blockstates') -Recurse -File -Filter *.json | ForEach-Object {
  $t = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
  foreach ($m in [regex]::Matches($t, '"model"\s*:\s*"([^"]+)"')) {
    $id = $m.Groups[1].Value
    if ($id -like 'minecraft:*') { continue }
    $path = Join-Path (Join-Path $assets 'models') (($id -replace '^tfc_food_port:', '') -replace '/', '\')
    if (-not (Test-Path ($path + '.json'))) { Write-Output ('MISSING MODEL ' + $id + '  (referenced by blockstate ' + $_.Name + ')'); $modelMissing++ }
  }
}
Write-Output ("blockstate -> model references missing: $modelMissing")

# ---- 2. every model parent exists, and every tfc_food_port texture exists ----
$parentMissing = 0; $texMissing = 0
Get-ChildItem (Join-Path $assets 'models') -Recurse -File -Filter *.json | ForEach-Object {
  $t = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
  foreach ($m in [regex]::Matches($t, '"parent"\s*:\s*"([^"]+)"')) {
    $id = $m.Groups[1].Value
    if ($id -like 'minecraft:*') { continue }
    $path = Join-Path (Join-Path $assets 'models') (($id -replace '^tfc_food_port:', '') -replace '/', '\')
    if (-not (Test-Path ($path + '.json'))) { Write-Output ('MISSING PARENT ' + $id + '  (in ' + $_.Name + ')'); $parentMissing++ }
  }
  foreach ($m in [regex]::Matches($t, '"textures"\s*:\s*\{([^}]*)\}', 'Singleline')) {
    foreach ($mm in [regex]::Matches($m.Groups[1].Value, ':\s*"tfc_food_port:([^"]+)"')) {
      $p = Join-Path (Join-Path $assets 'textures') (($mm.Groups[1].Value) -replace '/', '\')
      if (-not (Test-Path ($p + '.png'))) { Write-Output ('MISSING TEXTURE tfc_food_port:' + $mm.Groups[1].Value + '  (in ' + $_.Name + ')'); $texMissing++ }
    }
  }
}
Write-Output ("model parents missing: $parentMissing   textures missing: $texMissing")

# ---- 3. every registered item/block with a model? ----
$itemModels = Get-ChildItem (Join-Path $assets 'models\item') -Recurse -File -Filter *.json | ForEach-Object {
  ($_.FullName.Substring((Join-Path $assets 'models\item').Length + 1) -replace '\\', '/' -replace '\.json$', '')
}
Write-Output ("item models: " + $itemModels.Count + "   blockstates: " + (Get-ChildItem (Join-Path $assets 'blockstates') -Recurse -File).Count)

# ---- 4. item ids referenced by data files must exist; block ids must NOT be checked here ----
# Only "name"/"id" fields hold item ids. Fields like "block" (block_state_property), "random_sequence",
# "feature" and "biomes" hold other kinds of ids, and a bush has no item at all now, so mixing them up
# produces false positives.
#
# A leaf is a legitimate exception: its item exists, but its model definition points at the BLOCK model rather than
# at a flat sprite, the way vanilla shows an oak leaves item. So a plant/<x>_leaves id is satisfied by a definition
# under assets/<ns>/items/plant/<x>_leaves.json, not by a models/item entry. Checking the definition directory as
# well as the model directory is what makes this rule tell the truth for both kinds of item.
$itemDefs = Get-ChildItem (Join-Path $assets 'items') -Recurse -File -Filter *.json | ForEach-Object {
  ($_.FullName.Substring((Join-Path $assets 'items').Length + 1) -replace '\\', '/' -replace '\.json$', '')
}
$dangling = 0
Get-ChildItem $data -Recurse -File -Filter *.json | ForEach-Object {
  $t = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
  foreach ($m in [regex]::Matches($t, '"(?:name|id)"\s*:\s*"(tfc_food_port:(?:food|seeds|plant)[a-z0-9_/]*)"')) {
    $id = $m.Groups[1].Value -replace '^tfc_food_port:', ''
    if (($itemModels -notcontains $id) -and ($itemDefs -notcontains $id)) {
      Write-Output ('DATA item id with no model: tfc_food_port:' + $id + '  (in ' + $_.Name + ')'); $dangling++
    }
  }
}
Write-Output ("data item ids missing a model: $dangling")

# ---- 5. blockstate variant completeness ----
# Each block needs an entry for every value of its blockstate properties, or the client bakes the missing model.
# Vanilla CropBlock always has 8 age states (AGE_7) regardless of how many stages a crop grows through;
# a SaplingBlock has 2 stage values; a bush has 4 age values; the banana bunch is directional, so it needs every
# age for every horizontal facing. Leaves and the barrel have no properties at all, so they legitimately use the
# single "" variant key.
$badStates = 0
Get-ChildItem (Join-Path $assets 'blockstates') -Recurse -File -Filter *.json | ForEach-Object {
  $t = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
  $prop = $null; $required = 0

  # The bunch is the one directional plant block: 3 ages x 4 facings, the same layout vanilla cocoa uses.
  if ($_.FullName -match 'blockstates\\plant\\banana_bunch\.json$') {
    $ages = 0; $facings = 0
    for ($i = 0; $i -lt 3; $i++) { if ($t -match ('"age=' + $i + ',')) { $ages++ } }
    foreach ($f in @('north', 'south', 'east', 'west')) { if ($t -match ('facing=' + $f + '"')) { $facings++ } }
    if ($ages -ne 3 -or $facings -ne 4) {
      Write-Output ('BLOCKSTATE INCOMPLETE ' + $_.Name + '  has ' + $ages + ' ages and ' + $facings + ' facings, needs 3 and 4')
      $badStates++
    }
    return
  }

  if ($_.FullName -match 'blockstates\\crop\\') { $prop = 'age'; $required = 8 }
  elseif ($_.FullName -match 'blockstates\\plant\\\w+_bush\.json$') { $prop = 'age'; $required = 4 }
  elseif ($_.FullName -match 'blockstates\\plant\\\w+_sapling\.json$') { $prop = 'stage'; $required = 2 }

  if ($prop) {
    # A "" variant key is Minecraft's catch-all: it covers every state, so it satisfies any property.
    if ($t -match '"variants"\s*:\s*\{\s*""') { return }

    $seen = @()
    for ($i = 0; $i -lt $required; $i++) { if ($t -match ('"' + $prop + '=' + $i + '"')) { $seen += $i } }
    if ($seen.Count -ne $required) {
      Write-Output ('BLOCKSTATE INCOMPLETE ' + $_.Name + '  has ' + $prop + ' [' + ($seen -join ',') + '] but needs 0..' + ($required - 1))
      $badStates++
    }
  } elseif ($t -notmatch '"variants"\s*:\s*\{\s*""') {
    Write-Output ('BLOCKSTATE WITHOUT PROPERTIES but no empty variant key: ' + $_.Name)
    $badStates++
  }
}
Write-Output ("blockstates with incomplete variant coverage: $badStates")

# ---- 6. every item has both a definition and a model ----
$defs = Get-ChildItem (Join-Path $assets 'items') -Recurse -File -Filter *.json | ForEach-Object {
  $_.FullName.Substring((Join-Path $assets 'items').Length + 1) -replace '\\', '/' -replace '\.json$', ''
}
$modelsFlat = Get-ChildItem (Join-Path $assets 'models\item') -Recurse -File -Filter *.json | ForEach-Object {
  $_.FullName.Substring((Join-Path $assets 'models\item').Length + 1) -replace '\\', '/' -replace '\.json$', ''
}
$noDef = $modelsFlat | Where-Object { $defs -notcontains $_ }
# A leaf item is a definition with no models/item counterpart by design: its icon is the leaf BLOCK model, the same
# way vanilla's oak leaves item uses the block. Reading those out of the block models keeps the count honest without
# hardcoding a fruit list here.
$leafDefs = Get-ChildItem (Join-Path $assets 'models\block\plant') -File -Filter '*_leaves.json' |
  ForEach-Object { 'plant/' + $_.BaseName }
$noModel = $defs | Where-Object { ($modelsFlat -notcontains $_) -and ($leafDefs -notcontains $_) }
Write-Output ("item models (177+)          : " + $modelsFlat.Count)
Write-Output ("item model definitions      : " + $defs.Count)
Write-Output ("models lacking a definition : " + @($noDef).Count)
$noDef | ForEach-Object { Write-Output ('  ! model without definition: ' + $_) }
Write-Output ("definitions lacking a model : " + @($noModel).Count + "   (" + @($leafDefs).Count + " leaf items use block models)")
$noModel | ForEach-Object { Write-Output ('  ! definition without model: ' + $_) }

# ---- 7. item model definitions must carry a real namespace ----
# A definition whose "model" reads "/food/cheese" (no namespace) makes the client log
# "Missing block model: minecraft:/food/cheese" and render the item as the missing model.
$badDef = 0
Get-ChildItem (Join-Path $assets 'items') -Recurse -File -Filter *.json | ForEach-Object {
  $t = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
  $m = [regex]::Match($t, '"model"\s*:\s*"([^"]+)"')
  if (-not $m.Success) { Write-Output ('DEFINITION WITHOUT MODEL ' + $_.Name); $badDef++ }
  elseif ($m.Groups[1].Value -notmatch '^[a-z0-9_.-]+:[a-z0-9_/.-]+$') {
    Write-Output ('MALFORMED MODEL ID in ' + $_.Name + ' -> ' + $m.Groups[1].Value)
    $badDef++
  }
}
Write-Output ("malformed item model definitions: $badDef")
