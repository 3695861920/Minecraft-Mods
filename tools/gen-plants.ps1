$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Generates every asset and data file for the ported plants.
#
#   berries   -> a four stage bush, harvested by hand, the berry itself is the seed
#   tree fruit -> an oak-trunked tree whose leaves drop the fruit; the fruit has a sapling and the fruit itself
#                 is plantable too
#
# Every plant is added to #minecraft:is_overworld, so bushes and trees appear in all overworld biomes.
# Pure ASCII script; all non-ASCII text lives in UTF-8 data files.

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
$tools = Join-Path $root 'tools'
$tfcJar = (Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File | Select-Object -First 1).FullName
$ns = 'tfc_food_port'
$assets = Join-Path $moduleDir "src\main\resources\assets\$ns"
$data = Join-Path $moduleDir "src\main\resources\data\$ns"
$vanillaData = Join-Path $moduleDir 'src\main\resources\data\minecraft'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function New-Dir([string]$p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Json([string]$path, [string]$json, [string]$mustContain) {
  if ($mustContain -and $json -notmatch [regex]::Escape($mustContain)) { throw ("generated json lost '$mustContain': " + $json) }
  New-Dir (Split-Path $path -Parent)
  [System.IO.File]::WriteAllText($path, $json, $utf8)
}

$bushBerries = @('blackberry', 'raspberry', 'blueberry', 'elderberry', 'gooseberry', 'bunchberry',
                 'strawberry', 'snowberry', 'cloudberry', 'wintergreen_berry', 'cranberry')
$treeFruits = @('banana', 'orange', 'lemon', 'peach', 'cherry', 'olive', 'green_apple', 'red_apple', 'plum')

$z = [System.IO.Compression.ZipFile]::OpenRead($tfcJar)
$entries = @{}
foreach ($e in $z.Entries) { if ($e.Length -gt 0) { $entries[$e.FullName] = $e } }

# ---------------------------------------------------------------- stale files from the old layouts
# 1. Berries used to have their own item; now the berry item places the bush, so those files must go.
# 2. Saplings are hidden: the fruit is the seed, so saplings must have NO item model and NO definition.
# 3. A stale bush-block texture/model set exists for tree fruits from before they became trees.
$stale = 0
foreach ($b in $bushBerries) {
  foreach ($p in @((Join-Path $assets "models\item\plant\$b`_bush.json"), (Join-Path $assets "items\plant\$b`_bush.json"))) {
    if (Test-Path $p) { Remove-Item $p -Force; $stale++ }
  }
}
foreach ($f in $treeFruits) {
  foreach ($p in @((Join-Path $assets "models\item\plant\$f`_sapling.json"), (Join-Path $assets "items\plant\$f`_sapling.json"),
                   (Join-Path $assets "models\item\plant\$f`_bush.json"), (Join-Path $assets "items\plant\$f`_bush.json"))) {
    if (Test-Path $p) { Remove-Item $p -Force; $stale++ }
  }
}
# the old four-stage "bush" textures/models/blockstates for what are now trees
Get-ChildItem (Join-Path $assets 'textures\block\plant') -File -Filter '*_stage_*.png' -ErrorAction SilentlyContinue |
  Where-Object { $treeFruits -contains ($_.Name -replace '_stage_\d+\.png$', '') } |
  ForEach-Object { Remove-Item $_.FullName -Force; $stale++ }
Get-ChildItem (Join-Path $assets 'models\block\plant') -File -Filter '*_bush_stage_*.json' -ErrorAction SilentlyContinue |
  Where-Object { $treeFruits -contains ($_.Name -replace '_bush_stage_\d+\.json$', '') } |
  ForEach-Object { Remove-Item $_.FullName -Force; $stale++ }
foreach ($f in $treeFruits) {
  $p = Join-Path $assets "blockstates\plant\$f`_bush.json"
  if (Test-Path $p) { Remove-Item $p -Force; $stale++ }
}
# NOTE: banana_leaves.png is NOT deleted here. It used to be, back when the banana borrowed vanilla's jungle
# leaves texture and had no image of its own; now gen-textures.ps1 writes it (vanilla's art with the jungle tint
# baked in), and deleting it here would remove the file again - the leaves would fall back to a missing texture
# whenever this script ran after that one.
# the first banana bunch attempt was a flat crossed model; the bunch is now vanilla cocoa geometry in three stages
$oldBunch = Join-Path $assets 'models\block\plant\banana_bunch.json'
if (Test-Path $oldBunch) { Remove-Item $oldBunch -Force; $stale++ }
Write-Output ("removed stale plant assets: " + $stale)

# ---------------------------------------------------------------- the shared leaf cube
# One cube model for every leaf in the port. It is deliberately NOT minecraft:block/leaves, because that model puts
# "tintindex": 0 on all six faces and asks for a biome foliage colour; a custom leaf block has no colour provider, so
# the tint comes back white and a greyscale texture renders grey-white. The port's leaf textures are pre-coloured,
# so no tint is wanted. See the leaf model generation below for the full story.
$leafBase = @'
{
  "parent": "minecraft:block/block",
  "textures": {
    "particle": "#all"
  },
  "elements": [
    {
      "from": [0, 0, 0],
      "to": [16, 16, 16],
      "faces": {
        "down":  { "uv": [0, 0, 16, 16], "texture": "#all", "cullface": "down" },
        "up":    { "uv": [0, 0, 16, 16], "texture": "#all", "cullface": "up" },
        "north": { "uv": [0, 0, 16, 16], "texture": "#all", "cullface": "north" },
        "south": { "uv": [0, 0, 16, 16], "texture": "#all", "cullface": "south" },
        "west":  { "uv": [0, 0, 16, 16], "texture": "#all", "cullface": "west" },
        "east":  { "uv": [0, 0, 16, 16], "texture": "#all", "cullface": "east" }
      }
    }
  ]
}
'@
Write-Json (Join-Path $assets 'models\block\plant\leaves_base.json') $leafBase '"texture": "#all"'

# ---------------------------------------------------------------- translation suffixes
# All non-ASCII text lives in UTF-8 data files: PS 5.1 reads .ps1 itself as GBK, so literal Chinese in this script
# is a syntax error.
$suffixEn = 'Sapling'; $suffixZh = ''
$leavesEn = 'Leaves'; $leavesZh = ''
$bunchEn = 'Banana Bunch'; $bunchZh = ''
foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $tools 'sapling-suffix.tsv'), [System.Text.Encoding]::UTF8)) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  $p = $line.TrimStart([char]0xFEFF) -split "`t"
  if ($p.Count -ge 3) { $suffixEn = $p[1].Trim(); $suffixZh = $p[2].Trim() }
}
foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $tools 'plant-suffix.tsv'), [System.Text.Encoding]::UTF8)) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  $p = $line.TrimStart([char]0xFEFF) -split "`t"
  if ($p.Count -lt 3) { continue }
  switch ($p[0].Trim()) {
    'leaves' { $leavesEn = $p[1].Trim(); $leavesZh = $p[2].Trim() }
    'bunch'  { $bunchEn = $p[1].Trim(); $bunchZh = $p[2].Trim() }
  }
}
$langEn = [System.IO.File]::ReadAllText((Join-Path $assets 'lang\en_us.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$langZh = [System.IO.File]::ReadAllText((Join-Path $assets 'lang\zh_cn.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json

# TFC's own translations, so leaves reuse TFC's names instead of an invented one.
# The tsv holds: key <tab> chinese <tab> english
$nameMap = @{}
$tfcLang = Join-Path $tools 'out\lang_filtered.tsv'
if (Test-Path $tfcLang) {
  foreach ($line in [System.IO.File]::ReadAllLines($tfcLang, [System.Text.Encoding]::UTF8)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $p = $line.TrimStart([char]0xFEFF) -split "`t"
    if ($p.Count -ge 3) { $nameMap[$p[0].Trim()] = @($p[2].Trim(), $p[1].Trim()) }
  }
}
Write-Output ("TFC translation rows available: " + $nameMap.Count)
function LangValue($table, [string]$key) {
  $p = $table.PSObject.Properties | Where-Object { $_.Name -eq $key } | Select-Object -First 1
  if ($p) { return [string]$p.Value } else { return $null }
}

$newLang = New-Object System.Collections.Generic.List[string]
foreach ($f in $treeFruits) {
  $en = LangValue $langEn "item.$ns.food.$f"
  $zh = LangValue $langZh "item.$ns.food.$f"
  if (-not $en) { $en = $f }
  if (-not $zh) { $zh = $f }

  # sapling name: "<Fruit> Sapling"
  $newLang.Add("block.$ns.plant.$f`_sapling`t" + $en + ' ' + $suffixEn + "`t" + $zh + $suffixZh)

  # leaves name: prefer TFC's own translation, otherwise "<Fruit> Leaves". The leaf item shares the block's name,
  # because shears or Silk Touch hand back the block itself - exactly like vanilla oak leaves, where there is no
  # separate "leaves item" with its own name.
  $tfcLeaves = $nameMap["block.tfc.plant.$f`_leaves"]
  if ($tfcLeaves) {
    $leafEn = $tfcLeaves[0]; $leafZh = $tfcLeaves[1]
  } else {
    $leafEn = $en + ' ' + $leavesEn; $leafZh = $zh + $leavesZh
  }
  $newLang.Add("block.$ns.plant.$f`_leaves`t" + $leafEn + "`t" + $leafZh)
  $newLang.Add("item.$ns.plant.$f`_leaves`t" + $leafEn + "`t" + $leafZh)
}

# the banana's trunk-hugging fruit block
$newLang.Add("block.$ns.plant.banana_bunch`t" + $bunchEn + "`t" + $bunchZh)
$extraPath = Join-Path $tools 'extra-lang.tsv'
$extraText = [System.IO.File]::ReadAllText($extraPath, [System.Text.Encoding]::UTF8)
$addedLang = 0
foreach ($row in $newLang) {
  $k = $row.Split("`t")[0]
  if ($extraText -notmatch ('(?m)^' + [regex]::Escape($k) + "`t")) { $extraText += $row + "`n"; $addedLang++ }
}
[System.IO.File]::WriteAllText($extraPath, $extraText, $utf8)

# ---------------------------------------------------------------- bushes (berries)
foreach ($b in $bushBerries) {
  $stages = @("berry_bush/dry_$b`_bush", "berry_bush/$b`_bush", "berry_bush/flowering_$b`_bush", "berry_bush/fruiting_$b`_bush")
  for ($i = 0; $i -lt 4; $i++) {
    $src = 'assets/tfc/textures/block/' + $stages[$i] + '.png'
    if (-not $entries.ContainsKey($src)) { throw ("missing TFC texture " + $src) }
    $out = Join-Path $assets "textures\block\plant\$b`_stage_$i.png"
    New-Dir (Split-Path $out -Parent)
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entries[$src], $out, $true)
  }

  for ($i = 0; $i -lt 4; $i++) {
    Write-Json (Join-Path $assets "models\block\plant\$b`_bush_stage_$i.json") `
      "{`n  `"parent`": `"minecraft:block/cross`",`n  `"textures`": {`n    `"cross`": `"${ns}:block/plant/$b`_stage_$i`"`n  }`n}`n" "${ns}:block/plant"
  }

  $variants = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt 4; $i++) { $variants.Add("    `"age=$i`": {`n      `"model`": `"${ns}:block/plant/$b`_bush_stage_$i`"`n    }") }
  Write-Json (Join-Path $assets "blockstates\plant\$b`_bush.json") ("{`n  `"variants`": {`n" + ($variants -join ",`n") + "`n  }`n}`n") "${ns}:block/plant"

  # Loot: a bush has no item of its own - the berry is its seed - so tearing one down is a lottery, not a harvest.
  #
  # 5% of bushes give a berry by hand, and minecraft:table_bonus reads the breaking tool's Fortune level and picks
  # the matching entry out of the list, so Fortune I/II/III give 10/15/20%: one extra 5% per level, exactly as asked
  # for. table_bonus is the right vanilla condition here (gravel's flint uses it) because it reads
  # LootContextParams.TOOL, which is what a block break supplies. Vanilla's
  # random_chance_with_enchanted_bonus looks the enchantment up on LootContextParams.ATTACKING_ENTITY, which only
  # ever exists for entity loot, so on a block it would silently ignore Fortune and always use the base chance.
  #
  # Harvesting a ripe bush by hand is still a guaranteed berry - that is TFCBerryBushBlock#useWithoutItem, not a
  # loot table - so a player never has to rely on this roll to get a berry back.
  $berryItem = "${ns}:food/$b"
  $loot = @"
{
  "type": "minecraft:block",
  "pools": [
    {
      "bonus_rolls": 0.0,
      "rolls": 1.0,
      "conditions": [
        { "condition": "minecraft:survives_explosion" },
        {
          "condition": "minecraft:table_bonus",
          "enchantment": "minecraft:fortune",
          "chances": [0.05, 0.1, 0.15, 0.2]
        }
      ],
      "entries": [
        { "type": "minecraft:item", "name": "$berryItem" }
      ]
    }
  ],
  "random_sequence": "${ns}:blocks/plant/$b`_bush"
}
"@
  Write-Json (Join-Path $data "loot_table\blocks\plant\$b`_bush.json") $loot "${ns}:food/"
}

# ---------------------------------------------------------------- trees (tree fruits)
# The banana is a palm: its "leaves" use vanilla jungle leaves texture and a palm-frond shape, and its fruit
# grows stuck to the trunk like cocoa instead of hanging in the canopy.
$treeFeatures = New-Object System.Collections.Generic.List[string]
foreach ($f in $treeFruits) {
  $isBanana = ($f -eq 'banana')

  # sapling texture always comes from TFC; leaves normally do too, except the banana which uses vanilla jungle leaves
  $saplingSrc = "assets/tfc/textures/block/fruit_tree/$f`_sapling.png"
  if (-not $entries.ContainsKey($saplingSrc)) { throw ("missing TFC texture " + $saplingSrc) }
  $saplingOut = Join-Path $assets "textures\block\plant\$f`_sapling.png"
  New-Dir (Split-Path $saplingOut -Parent)
  [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entries[$saplingSrc], $saplingOut, $true)

  if (-not $isBanana) {
    $leavesSrc = "assets/tfc/textures/block/fruit_tree/$f`_leaves.png"
    if (-not $entries.ContainsKey($leavesSrc)) { throw ("missing TFC texture " + $leavesSrc) }
    $leavesOut = Join-Path $assets "textures\block\plant\$f`_leaves.png"
    New-Dir (Split-Path $leavesOut -Parent)
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entries[$leavesSrc], $leavesOut, $true)
  }

  # sapling model: a cross, same as vanilla saplings
  Write-Json (Join-Path $assets "models\block\plant\$f`_sapling.json") `
    "{`n  `"parent`": `"minecraft:block/cross`",`n  `"textures`": {`n    `"cross`": `"${ns}:block/plant/$f`_sapling`"`n  }`n}`n" "${ns}:block/plant"

  # Every leaf parents OUR OWN cube rather than minecraft:block/leaves, and the reason is the banana:
  #
  # minecraft:block/leaves marks all six faces with "tintindex": 0, which asks the game for a biome foliage colour.
  # Vanilla's own leaf textures are greyscale masks that rely on that (jungle_leaves.png is #888787 / #B7B9B7 grey),
  # and vanilla registers a colour provider for each of its leaf blocks. A custom leaf block has no provider, so the
  # tint comes back white and a greyscale texture renders as grey-white - which is exactly how the banana's leaves
  # looked, since they were borrowing vanilla's texture.
  #
  # The port's leaf textures are all pre-coloured (TFC's art is already green, and the banana's is now vanilla's art
  # with the jungle tint baked in by gen-textures.ps1), so no tint is wanted at all. Parenting a tintless cube makes
  # that explicit and means no leaf can ever be washed out by an unexpected tint.
  Write-Json (Join-Path $assets "models\block\plant\$f`_leaves.json") `
    "{`n  `"parent`": `"${ns}:block/plant/leaves_base`",`n  `"textures`": {`n    `"all`": `"${ns}:block/plant/$f`_leaves`"`n  }`n}`n" "${ns}:block/plant"

  # ---- leaves loot ----
  # Two ways to break a leaf, exactly like vanilla oak leaves:
  #   - shears or Silk Touch take the LEAF BLOCK itself, which is why the leaves have a block item of their own
  #   - anything else only sometimes shakes a fruit loose: 5% by hand, +5% per Fortune level, via table_bonus
  #     (which reads the breaking tool - see the note in gen-recipes for why
  #     random_chance_with_enchanted_bonus cannot be used on a block loot table)
  # A whole crown is 20-60 leaves, so a tree still pays out a few fruits per harvest without every single leaf
  # being worth one. The sapling is never dropped: the fruit is the seed, so a sapling is only ever reached by
  # planting a fruit.
  #
  # The banana is the exception to the fruit half: its leaves are plain jungle leaves and give nothing but the
  # leaves themselves, so it has the shears/Silk Touch child and no fruit child.
  $leavesId = "${ns}:plant/$f`_leaves"
  $leavesChildren = @"
          {
            "type": "minecraft:item",
            "conditions": [
              {
                "condition": "minecraft:any_of",
                "terms": [
                  { "condition": "minecraft:match_tool", "predicate": { "items": "minecraft:shears" } },
                  {
                    "condition": "minecraft:match_tool",
                    "predicate": {
                      "predicates": {
                        "minecraft:enchantments": [
                          { "enchantments": "minecraft:silk_touch", "levels": { "min": 1 } }
                        ]
                      }
                    }
                  }
                ]
              }
            ],
            "name": "$leavesId"
          }
"@
  if (-not $isBanana) {
    $leavesChildren = $leavesChildren + @"
,
          {
            "type": "minecraft:item",
            "conditions": [
              { "condition": "minecraft:survives_explosion" },
              {
                "condition": "minecraft:table_bonus",
                "enchantment": "minecraft:fortune",
                "chances": [0.05, 0.1, 0.15, 0.2]
              }
            ],
            "name": "${ns}:food/$f"
          }
"@
  }
  # The apple trees have a second, much rarer prize: a golden apple, and a vanishingly rare enchanted one. These
  # use minecraft:random_chance rather than table_bonus, because the requested rates are the whole point and must
  # NOT be scaled up by Fortune - a 0.1% find stays 0.1% however the player breaks the leaves.
  #
  # Only the apples get this. Oranges and plums giving golden apples would make the trees indistinguishable.
  $rarePools = ''
  if ($f -eq 'red_apple' -or $f -eq 'green_apple') {
    $rarePools = @"
,
    {
      "bonus_rolls": 0.0,
      "rolls": 1.0,
      "conditions": [
        { "condition": "minecraft:survives_explosion" },
        { "condition": "minecraft:random_chance", "chance": 0.001 }
      ],
      "entries": [
        { "type": "minecraft:item", "name": "minecraft:golden_apple" }
      ]
    },
    {
      "bonus_rolls": 0.0,
      "rolls": 1.0,
      "conditions": [
        { "condition": "minecraft:survives_explosion" },
        { "condition": "minecraft:random_chance", "chance": 0.0001 }
      ],
      "entries": [
        { "type": "minecraft:item", "name": "minecraft:enchanted_golden_apple" }
      ]
    }
"@
  }

  $leavesLoot = @"
{
  "type": "minecraft:block",
  "pools": [
    {
      "bonus_rolls": 0.0,
      "rolls": 1.0,
      "entries": [
        {
          "type": "minecraft:alternatives",
          "children": [
$leavesChildren
          ]
        }
      ]
    }$rarePools
  ],
  "random_sequence": "${ns}:blocks/plant/$f`_leaves"
}
"@
  Write-Json (Join-Path $data "loot_table\blocks\plant\$f`_leaves.json") $leavesLoot "${ns}:plant/$f`_leaves"

  # ---- sapling loot: the fruit, because a sapling can only be reached by planting a fruit ----
  $saplingLoot = @"
{
  "type": "minecraft:block",
  "pools": [
    {
      "bonus_rolls": 0.0,
      "rolls": 1.0,
      "conditions": [
        { "condition": "minecraft:survives_explosion" }
      ],
      "entries": [
        { "type": "minecraft:item", "name": "${ns}:food/$f" }
      ]
    }
  ],
  "random_sequence": "${ns}:blocks/plant/$f`_sapling"
}
"@
  Write-Json (Join-Path $data "loot_table\blocks\plant\$f`_sapling.json") $saplingLoot "${ns}:food/"

  # ---- the tree itself: vanilla oak trunk, our leaves ----
  # The banana grows as a palm: a tall bare trunk with a flat crown of fronds on top.
  #
  # The crown must use acacia_foliage_placer, not blob_foliage_placer. A blob with radius 1 / height 1 works out to
  # "leafRadius - 1 - yo / 2" clamped at 0, so it places exactly two leaf blocks at the very top of an 8 block trunk -
  # effectively an invisible tree, which is why the banana had no visible leaves and therefore dropped no fruit.
  # Acacia's placer lays a flat 5x5 row plus 3x3 rows, which is both visible and shaped like a palm crown.
  $trunkBase = 4; $trunkRand = 2
  $foliagePlacer = @"
    "foliage_placer": {
      "type": "minecraft:blob_foliage_placer",
      "height": 3,
      "offset": 0,
      "radius": 2
    },
"@
  if ($isBanana) {
    $trunkBase = 7; $trunkRand = 2
    $foliagePlacer = @"
    "foliage_placer": {
      "type": "minecraft:acacia_foliage_placer",
      "offset": 0,
      "radius": 2
    },
"@
  }

  # Wild banana palms must actually carry bananas, otherwise the fruit could only ever be obtained by planting one
  # by hand. minecraft:attached_to_leaves is the generic vanilla decorator for hanging a block off the canopy (it is
  # what vanilla uses for mangrove propagules), and bunches hang on the LEAVES here, not on the trunk.
  # A ripe age is used so the bunches are ready to break.
  $decorators = '    "decorators": [],'
  if ($isBanana) {
    $decorators = @"
    "decorators": [
      {
        "type": "minecraft:attached_to_leaves",
        "probability": 0.35,
        "exclusion_radius_xz": 3,
        "exclusion_radius_y": 3,
        "required_empty_blocks": 1,
        "block_provider": {
          "type": "minecraft:simple_state_provider",
          "state": {
            "Name": "${ns}:plant/banana_bunch",
            "Properties": {
              "facing": "north",
              "age": "2"
            }
          }
        },
        "directions": [
          "north",
          "south",
          "east",
          "west",
          "down"
        ]
      }
    ],
"@
    if ($decorators -notmatch [regex]::Escape($ns + ':plant/banana_bunch')) { throw 'banana decorator lost its namespace' }
  }

  # TreeGrower resolves a configured feature by key, so this file is what the sapling grows into.
  $configured = @"
{
  "type": "minecraft:tree",
  "config": {
    "below_trunk_provider": {
      "type": "minecraft:rule_based_state_provider",
      "rules": [
        {
          "if_true": {
            "type": "minecraft:not",
            "predicate": {
              "type": "minecraft:matching_block_tag",
              "tag": "minecraft:cannot_replace_below_tree_trunk"
            }
          },
          "then": {
            "type": "minecraft:simple_state_provider",
            "state": { "Name": "minecraft:dirt" }
          }
        }
      ]
    },
$decorators
$foliagePlacer    "foliage_provider": {
      "type": "minecraft:simple_state_provider",
      "state": {
        "Name": "$leavesId",
        "Properties": {
          "distance": "7",
          "persistent": "false",
          "waterlogged": "false"
        }
      }
    },
    "ignore_vines": true,
    "minimum_size": {
      "type": "minecraft:two_layers_feature_size",
      "limit": 1,
      "lower_size": 0,
      "upper_size": 1
    },
    "trunk_placer": {
      "type": "minecraft:straight_trunk_placer",
      "base_height": $trunkBase,
      "height_rand_a": $trunkRand,
      "height_rand_b": 0
    },
    "trunk_provider": {
      "type": "minecraft:simple_state_provider",
      "state": {
        "Name": "minecraft:oak_log",
        "Properties": { "axis": "y" }
      }
    }
  }
}
"@
  Write-Json (Join-Path $data "worldgen\configured_feature\$f`_tree.json") $configured "$leavesId"

  # ---- blockstates for the sapling and the leaves ----
  # The sapling model is a cross with no properties, so the catch-all "" key is correct; the leaves model is also
  # a single model for every distance/persistent/waterlogged state.
  foreach ($pair in @(@("$f`_sapling", 'sapling'), @("$f`_leaves", 'leaves'))) {
    $state = "{`n  `"variants`": {`n    `"`": {`n      `"model`": `"${ns}:block/plant/$f`_$($pair[1])`"`n    }`n  }`n}`n"
    if ($state -notmatch [regex]::Escape($ns + ':block/plant/')) { throw 'plant blockstate lost its namespace' }
    Write-Json (Join-Path $assets "blockstates\plant\$($pair[0]).json") $state "${ns}:block/plant"
  }

  # ---- the leaf item ----
  # A leaf is a real block item (shears or Silk Touch take it), and its icon deliberately uses the BLOCK model
  # rather than a flat sprite, the same way vanilla shows an oak leaves item.
  #
  # Its definition is NOT written here: assets/<ns>/items/ belongs to gen-item-definitions.ps1, which wipes the
  # directory before rebuilding it, so anything this script wrote there would be deleted the next time that script
  # ran. The block name is added to extra-lang.tsv above, next to the item name that script's item list provides.

  # ---- banana only: the hanging bunch, its assets and its loot ----
  if ($isBanana) {
    # Geometry is vanilla cocoa's, reused directly by parenting its stage models and swapping the texture variable.
    # Cocoa's pod already has the depth a banana bunch needs, and parenting means the shape can never drift from
    # vanilla's. Each stage points at its OWN recoloured image (banana_bunch_stage<age>), so the bunch visibly
    # ripens from green to yellow; the earlier version pointed all three stages at one image, which is why a ripe
    # bunch looked like an unripe one. Those images are drawn by gen-textures.ps1 from vanilla's cocoa textures.
    foreach ($stage in @(0, 1, 2)) {
      $stageModel = "{`n  `"parent`": `"minecraft:block/cocoa_stage$stage`",`n  `"textures`": {`n    `"cocoa`": `"${ns}:block/plant/banana_bunch_stage$stage`",`n    `"particle`": `"${ns}:block/plant/banana_bunch_stage$stage`"`n  }`n}`n"
      if ($stageModel -notmatch [regex]::Escape($ns + ':block/plant/banana_bunch_stage')) { throw 'banana bunch model lost its namespace' }
      Write-Json (Join-Path $assets "models\block\plant\banana_bunch_stage$stage.json") $stageModel "${ns}:block/plant"
    }

    # Same variant layout as vanilla cocoa's blockstate: three ages x four facings, rotated a quarter turn each.
    $bunchVariants = New-Object System.Collections.Generic.List[string]
    $facings = @(
      @{ name = 'south'; y = 0 },
      @{ name = 'west'; y = 90 },
      @{ name = 'north'; y = 180 },
      @{ name = 'east'; y = 270 }
    )
    foreach ($stage in @(0, 1, 2)) {
      foreach ($fc in $facings) {
        if ($fc.y -eq 0) {
          $bunchVariants.Add("    `"age=$stage,facing=$($fc.name)`": {`n      `"model`": `"${ns}:block/plant/banana_bunch_stage$stage`"`n    }")
        } else {
          $bunchVariants.Add("    `"age=$stage,facing=$($fc.name)`": {`n      `"model`": `"${ns}:block/plant/banana_bunch_stage$stage`",`n      `"y`": $($fc.y)`n    }")
        }
      }
    }
    $bunchState = "{`n  `"variants`": {`n" + ($bunchVariants -join ",`n") + "`n  }`n}`n"
    if ($bunchState -notmatch [regex]::Escape($ns + ':block/plant/')) { throw 'banana bunch blockstate lost its namespace' }
    Write-Json (Join-Path $assets 'blockstates\plant\banana_bunch.json') $bunchState "${ns}:block/plant"

    # Loot only ever yields bananas. The bunch deliberately has no item at all, so silk touch cannot pick up the
    # block either - breaking it always gives fruit, never a placeable block.
    #
    # Only a ripe bunch (age 2) pays out, exactly like vanilla cocoa, and it pays out exactly 3 bananas. Fortune
    # adds one banana per level: binomial_with_bonus_count rolls one extra round per level at probability 1, which
    # makes the "binomial" deterministic, so Fortune III is exactly 6. uniform_bonus_count would add a random 0..3
    # instead and leave the Fortune III number wandering between 3 and 6.
    $bunchId = "${ns}:plant/banana_bunch"
    $bunchLoot = @"
{
  "type": "minecraft:block",
  "pools": [
    {
      "bonus_rolls": 0.0,
      "rolls": 1.0,
      "conditions": [
        { "condition": "minecraft:survives_explosion" },
        {
          "condition": "minecraft:block_state_property",
          "block": "$bunchId",
          "properties": { "age": "2" }
        }
      ],
      "entries": [
        {
          "type": "minecraft:item",
          "name": "${ns}:food/banana",
          "functions": [
            {
              "function": "minecraft:set_count",
              "add": false,
              "count": 3
            },
            {
              "function": "minecraft:apply_bonus",
              "enchantment": "minecraft:fortune",
              "formula": "minecraft:binomial_with_bonus_count",
              "parameters": { "extra": 0, "probability": 1.0 }
            }
          ]
        }
      ]
    }
  ],
  "random_sequence": "${ns}:blocks/plant/banana_bunch"
}
"@
    Write-Json (Join-Path $data 'loot_table\blocks\plant\banana_bunch.json') $bunchLoot "${ns}:food/"
  }

  # ---- its placed feature: a rare single tree on grass/dirt, standing on the ground ----
  $placed = @"
{
  "feature": "${ns}:$f`_tree",
  "placement": [
    { "type": "minecraft:rarity_filter", "chance": 12 },
    { "type": "minecraft:in_square" },
    {
      "type": "minecraft:heightmap",
      "heightmap": "OCEAN_FLOOR"
    },
    {
      "type": "minecraft:block_predicate_filter",
      "predicate": {
        "type": "minecraft:would_survive",
        "state": {
          "Name": "${ns}:plant/$f`_sapling",
          "Properties": { "stage": "0" }
        }
      }
    }
  ]
}
"@
  Write-Json (Join-Path $data "worldgen\placed_feature\trees_$f.json") $placed "${ns}:plant/"
  $treeFeatures.Add("${ns}:trees_$f")
}

$z.Dispose()

# ---------------------------------------------------------------- stale worldgen from the old "everything is a bush" layout
# Tree fruits used to be bushes; those features referenced plant/<fruit>_bush, which no longer exists, so leaving
# them behind would break datapack loading.
$staleFeatures = 0
foreach ($f in $treeFruits) {
  foreach ($p in @((Join-Path $data "worldgen\configured_feature\patch_$f`_bush.json"),
                   (Join-Path $data "worldgen\placed_feature\patch_$f`_bush.json"),
                   (Join-Path $data "loot_table\blocks\plant\$f`_bush.json"))) {
    if (Test-Path $p) { Remove-Item $p -Force; $staleFeatures++ }
  }
}
Write-Output ("removed stale tree-fruit bush features/loot: " + $staleFeatures)

# ---------------------------------------------------------------- #minecraft:leaves
# Custom leaf blocks are NOT part of a vanilla tag just because they extend LeavesBlock, and "is this a leaf?" is
# answered by the tag everywhere it matters - including in this mod: the banana bunch survives on a leaf and a
# banana is planted onto one. Without this file a bunch would drop off its own leaf the first time a neighbouring
# block changed, and a banana would refuse to plant in mid air next to one.
New-Dir (Join-Path $vanillaData 'tags\block')
$leafEntries = New-Object System.Collections.Generic.List[string]
foreach ($f in $treeFruits) { $leafEntries.Add("    `"${ns}:plant/$f`_leaves`"") }
$leafTag = "{`n  `"replace`": false,`n  `"values`": [`n" + ($leafEntries -join ",`n") + "`n  ]`n}`n"
Write-Json (Join-Path $vanillaData 'tags\block\leaves.json') $leafTag "${ns}:plant/"

# ---------------------------------------------------------------- world generation
# One modifier adding every bush patch and every tree to all overworld biomes.
$features = New-Object System.Collections.Generic.List[string]
foreach ($b in $bushBerries) { $features.Add("    `"${ns}:patch_$b`_bush`"") }
foreach ($t in $treeFeatures) { $features.Add("    `"$t`"") }
$modifier = "{`n  `"type`": `"neoforge:add_features`",`n  `"biomes`": `"#minecraft:is_overworld`",`n  `"features`": [`n" + ($features -join ",`n") + "`n  ],`n  `"step`": `"vegetal_decoration`"`n}`n"
Write-Json (Join-Path $data 'neoforge\biome_modifier\plants_all_biomes.json') $modifier '#minecraft:is_overworld'

# drop the old per-biome-group modifiers, they are superseded
$oldMods = @('berry_bushes_forest.json', 'berry_bushes_plains.json', 'berry_bushes_taiga.json', 'berry_bushes_jungle.json')
$removed = 0
foreach ($m in $oldMods) {
  $p = Join-Path $data "neoforge\biome_modifier\$m"
  if (Test-Path $p) { Remove-Item $p -Force; $removed++ }
}

Write-Output ("bush berries : " + $bushBerries.Count)
Write-Output ("tree fruits  : " + $treeFruits.Count)
Write-Output ("new sapling translations: " + $addedLang)
Write-Output ("removed old biome modifiers: " + $removed + "  (replaced by plants_all_biomes.json)")
