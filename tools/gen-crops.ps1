$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Pure ASCII script: PS 5.1 reads .ps1 as GBK, so all non-ASCII text lives in UTF-8 data files.
# Locate the TerraFirmaCraft jar without hardcoding where this machine keeps it. These scripts live in
# <root>/tools and the jar is expected in the project root, so the path is derived rather than globbed. The previous
# version searched an absolute path, which meant the generators could only run on one machine - and could not run in
# CI at all, where the release workflow downloads the jar into exactly this root.
$root = Split-Path $PSScriptRoot -Parent
$tfcJarFile = Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $tfcJarFile) { throw ('no TerraFirmaCraft jar in ' + $root + ': these generators read TFC textures and data out of it') }
$jar = $tfcJarFile.FullName

# Resources are written into the selected target's module rather than into the repository root. See tools/targets.ps1.
. (Join-Path $PSScriptRoot 'targets.ps1')
$moduleDir = Get-ModuleDir $root
$root = Split-Path $jar -Parent
$tools = Join-Path $root 'tools'
$res = Join-Path $moduleDir 'src\main\resources'
$assets = Join-Path $res 'assets\tfc_food_port'
$data = Join-Path $res 'data\tfc_food_port'

function New-Dir([string]$path) { if (-not (Test-Path $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null } }
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Builds one loot pool holding a single item, optionally gated on a crop age. Emits strictly valid JSON.
function New-Pool {
  param([string]$Crop, [string]$AgeCond, [string]$Item, [double]$Min, [double]$Max)
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('        {')
  $lines.Add('          "condition": "minecraft:survives_explosion"')
  $lines.Add('        }')
  $outerConds = $lines -join "`n"

  if ($Min -ne $Max) {
    $countJson = "{`n                `"type`": `"minecraft:uniform`",`n                `"min`": $Min,`n                `"max`": $Max`n              }"
  } else {
    $countJson = "$Min"
  }

  $entry = New-Object System.Collections.Generic.List[string]
  $entry.Add('        {')
  $entry.Add('          "type": "minecraft:item",')
  $entry.Add('          "name": "' + $Item + '",')
  if ($AgeCond -ne '') {
    $entry.Add('          "conditions": [')
    $entry.Add('            {')
    $entry.Add('              "condition": "minecraft:block_state_property",')
    $entry.Add('              "block": "tfc_food_port:crop/' + $Crop + '",')
    $entry.Add('              "properties": {')
    $entry.Add('                "age": "' + $AgeCond + '"')
    $entry.Add('              }')
    $entry.Add('            }')
    $entry.Add('          ],')
  }
  $entry.Add('          "functions": [')
  $entry.Add('            {')
  $entry.Add('              "function": "minecraft:set_count",')
  $entry.Add('              "add": false,')
  $entry.Add('              "count": ' + $countJson)
  $entry.Add('            }')
  $entry.Add('          ]')
  $entry.Add('        }')
  $entryJson = $entry -join "`n"

  return "    {`n      `"bonus_rolls`": 0.0,`n      `"rolls`": 1.0,`n      `"conditions`": [`n$outerConds`n      ],`n      `"entries`": [`n$entryJson`n      ]`n    }"
}

# ---------------------------------------------------------------- crop table
$crops = @(
  'barley','oat','rye','wheat','rice','maize',
  'beet','cabbage','carrot','garlic','onion','potato',
  'green_bean','lentil','soybean','peanut','radish','cassava','squash',
  'tomato','red_bell_pepper','yellow_bell_pepper',
  'pumpkin','melon','sugarcane'
)

# product id per crop; pumpkin and melon produce the vanilla block, everything else the ported food item
$products = @{}
foreach ($c in $crops) { $products[$c] = 'tfc_food_port:food/' + $c }
$products['pumpkin'] = 'minecraft:pumpkin'
$products['melon'] = 'minecraft:melon'

# only these are single-fruit drops instead of a handful
$single = @('pumpkin', 'melon')

# unripe product, given by a plant that is one stage short of fully grown
$early = @{
  'red_bell_pepper'    = 'tfc_food_port:food/green_bell_pepper'
  'yellow_bell_pepper' = 'tfc_food_port:food/green_bell_pepper'
}

# ---------------------------------------------------------------- TFC name map
$nameMap = @{}
foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $tools 'out\lang_filtered.tsv'), [System.Text.Encoding]::UTF8)) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  $p = $line.TrimStart([char]0xFEFF) -split "`t"
  if ($p.Count -ge 3) { $nameMap[$p[0].Trim()] = @($p[2].Trim(), $p[1].Trim()) }
}

# ---------------------------------------------------------------- append seed items + block names
$itemsPath = Join-Path $tools 'items.tsv'
$itemsText = [System.IO.File]::ReadAllText($itemsPath, [System.Text.Encoding]::UTF8)
$extraPath = Join-Path $tools 'extra-lang.tsv'
$extraText = [System.IO.File]::ReadAllText($extraPath, [System.Text.Encoding]::UTF8)
$seedRows = New-Object System.Collections.Generic.List[string]
$blockRows = New-Object System.Collections.Generic.List[string]
$nameMissing = New-Object System.Collections.Generic.List[string]

foreach ($c in $crops) {
  $seedKey = 'item.tfc.seeds.' + $c
  $blockKey = 'block.tfc.crop.' + $c
  if ($nameMap.ContainsKey($seedKey)) {
    if ($itemsText -notmatch ('(?m)^seeds/' + [regex]::Escape($c) + "`t")) {
      $seedRows.Add('seeds/' + $c + "`t" + $nameMap[$seedKey][0] + "`t" + $nameMap[$seedKey][1])
    }
  } else { $nameMissing.Add($seedKey) }
  if ($nameMap.ContainsKey($blockKey)) {
    $langKey = 'block.tfc_food_port.crop.' + $c
    if ($extraText -notmatch ('(?m)^' + [regex]::Escape($langKey) + "`t")) {
      $blockRows.Add($langKey + "`t" + $nameMap[$blockKey][0] + "`t" + $nameMap[$blockKey][1])
    }
  } else { $nameMissing.Add($blockKey) }
}

if ($seedRows.Count -gt 0) {
  if (-not $itemsText.EndsWith("`n")) { $itemsText += "`n" }
  [System.IO.File]::WriteAllText($itemsPath, $itemsText + ($seedRows -join "`n") + "`n", $utf8)
}
if ($blockRows.Count -gt 0) {
  if (-not $extraText.EndsWith("`n")) { $extraText += "`n" }
  [System.IO.File]::WriteAllText($extraPath, $extraText + ($blockRows -join "`n") + "`n", $utf8)
}

$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
$entries = @{}
foreach ($e in $z.Entries) { if ($e.Length -gt 0) { $entries[$e.FullName] = $e } }

# ---------------------------------------------------------------- per crop resources
$report = New-Object System.Collections.Generic.List[string]

foreach ($c in $crops) {
  # stage count straight from the jar, so blockstates and models always match TFC's textures
  $stages = 0
  while ($entries.ContainsKey("assets/tfc/textures/block/crop/$c`_$stages.png")) { $stages++ }
  if ($stages -lt 2) { throw ("no stage textures found for crop " + $c) }
  $maxAge = $stages - 1

  # --- block textures ---
  $texOutDir = Join-Path $assets "textures\block\crop"
  New-Dir $texOutDir
  for ($i = 0; $i -lt $stages; $i++) {
    $src = "assets/tfc/textures/block/crop/$c`_$i.png"
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entries[$src], (Join-Path $texOutDir "$c`_$i.png"), $true)
  }

  # --- block models ---
  $modelOutDir = Join-Path $assets "models\block\crop"
  New-Dir $modelOutDir
  for ($i = 0; $i -lt $stages; $i++) {
    $json = "{`n  `"parent`": `"minecraft:block/crop`",`n  `"textures`": {`n    `"crop`": `"tfc_food_port:block/crop/$c`_$i`"`n  }`n}`n"
    [System.IO.File]::WriteAllText((Join-Path $modelOutDir "$c`_$i.json"), $json, $utf8)
  }

  # --- blockstate ---
  # IMPORTANT: vanilla CropBlock registers its "age" property as the shared AGE_7 (0..7) in its own constructor,
  # before a subclass instance can provide a narrower range, so every crop block really has 8 age states even when
  # it only grows through fewer stages. All 8 must be given a model, otherwise the unused ages bake to the missing
  # model ("Missing model for variant: Block{tfc_food_port:crop/peanut}[age=6]").
  # Ages past the crop's last stage therefore just reuse the final stage's model; they are never reached in game
  # because getMaxAge() still reports the true stage count.
  $bsOutDir = Join-Path $assets 'blockstates\crop'
  New-Dir $bsOutDir
  $variants = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -le 7; $i++) {
    $stage = [Math]::Min($i, $stages - 1)
    $variants.Add("    `"age=$i`": {`n      `"model`": `"tfc_food_port:block/crop/$c`_$stage`"`n    }")
  }
  $bs = "{`n  `"variants`": {`n" + ($variants -join ",`n") + "`n  }`n}`n"
  [System.IO.File]::WriteAllText((Join-Path $bsOutDir "$c.json"), $bs, $utf8)

  # --- loot table ---
  $pools = New-Object System.Collections.Generic.List[string]
  if ($single -contains $c) {
    $pools.Add((New-Pool $c "$maxAge" $products[$c] 1.0 1.0))
  } else {
    $pools.Add((New-Pool $c "$maxAge" $products[$c] 1.0 3.0))
  }
  if ($early.ContainsKey($c)) {
    $pools.Add((New-Pool $c "$($maxAge - 1)" $early[$c] 1.0 3.0))
  }
  $pools.Add((New-Pool $c '' ("tfc_food_port:seeds/" + $c) 1.0 2.0))

  $lootDir = Join-Path $data "loot_table\blocks\crop"
  New-Dir $lootDir
  $loot = "{`n  `"type`": `"minecraft:block`",`n  `"pools`": [`n" + ($pools -join ",`n") + "`n  ],`n  `"random_sequence`": `"tfc_food_port:blocks/crop/$c`"`n}`n"
  [System.IO.File]::WriteAllText((Join-Path $lootDir "$c.json"), $loot, $utf8)

  $report.Add(("{0,-20} stages={1} maxAge={2} product={3}" -f $c, $stages, $maxAge, $products[$c]))
}
$z.Dispose()

# ---------------------------------------------------------------- seed acquisition from grass
# TFC gets its seeds from wild crops, which this port does not add. Instead the seeds are bootstrapped the vanilla
# way: breaking grass has a chance to drop one random crop seed. This uses only built-in NeoForge/vanilla pieces
# ("neoforge:add_table" plus a plain loot table), so no custom Java is needed.
$seedEntries = New-Object System.Collections.Generic.List[string]
foreach ($c in $crops) {
  $seedEntries.Add("        {`n          `"type`": `"minecraft:item`",`n          `"name`": `"tfc_food_port:seeds/$c`",`n          `"weight`": 1`n        }")
}
$subTable = "{`n  `"type`": `"minecraft:block`",`n  `"pools`": [`n    {`n      `"bonus_rolls`": 0.0,`n      `"rolls`": 1.0,`n      `"entries`": [`n" + ($seedEntries -join ",`n") + "`n      ]`n    }`n  ],`n  `"random_sequence`": `"tfc_food_port:grass_seeds`"`n}`n"
$lootRoot = Join-Path $data 'loot_table'
New-Dir $lootRoot
[System.IO.File]::WriteAllText((Join-Path $lootRoot 'grass_seeds.json'), $subTable, $utf8)

$modifier = @'
{
  "type": "neoforge:add_table",
  "conditions": [
    {
      "condition": "minecraft:any_of",
      "terms": [
        {
          "condition": "neoforge:loot_table_id",
          "loot_table_id": "minecraft:blocks/short_grass"
        },
        {
          "condition": "neoforge:loot_table_id",
          "loot_table_id": "minecraft:blocks/tall_grass"
        }
      ]
    },
    {
      "condition": "minecraft:random_chance",
      "chance": 0.125
    }
  ],
  "table": "tfc_food_port:grass_seeds"
}
'@
$modRoot = Join-Path $data 'loot_modifiers'
New-Dir $modRoot
[System.IO.File]::WriteAllText((Join-Path $modRoot 'add_crop_seeds_from_grass.json'), $modifier, $utf8)


Write-Output ("crops processed: " + $crops.Count)
Write-Output ("seed rows added: " + $seedRows.Count + "   block name rows added: " + $blockRows.Count)
if ($nameMissing.Count -gt 0) {
  Write-Output '--- missing TFC translations (add manually) ---'
  $nameMissing | ForEach-Object { Write-Output $_ }
}
Write-Output '--- crop detail ---'
$report | ForEach-Object { Write-Output $_ }
