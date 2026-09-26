$ErrorActionPreference = 'Stop'

# Loot for the port:
#   - rennet drops from cows and sheep (adds to the vanilla entity tables via NeoForge's built-in add_table modifier)
#   - fresh seaweed can be gathered from vanilla ocean plants
# Pure ASCII script.

# Locate the TerraFirmaCraft jar without hardcoding where this machine keeps it. These scripts live in
# <root>/tools and the jar is expected in the project root, so the path is derived rather than globbed. The previous
# version searched an absolute path, which meant the generators could only run on one machine - and could not run in
# CI at all, where the release workflow downloads the jar into exactly this root.
$root = Split-Path $PSScriptRoot -Parent
$tfcJarFile = Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $tfcJarFile) { throw ('no TerraFirmaCraft jar in ' + $root + ': these generators read TFC textures and data out of it') }
$jar = $tfcJarFile.FullName
$root = Split-Path $jar -Parent
$data = Join-Path $root 'src\main\resources\data\tfc_food_port'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function New-Dir([string]$path) { if (-not (Test-Path $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null } }

# ---------------------------------------------------------------- rennet subtable
$rennetTable = @'
{
  "type": "minecraft:entity",
  "pools": [
    {
      "bonus_rolls": 0.0,
      "rolls": 1.0,
      "entries": [
        {
          "type": "minecraft:item",
          "name": "tfc_food_port:rennet",
          "functions": [
            {
              "function": "minecraft:set_count",
              "add": false,
              "count": {
                "type": "minecraft:uniform",
                "min": 1.0,
                "max": 2.0
              }
            }
          ]
        }
      ]
    }
  ],
  "random_sequence": "tfc_food_port:rennet"
}
'@
New-Dir (Join-Path $data 'loot_table')
[System.IO.File]::WriteAllText((Join-Path $data 'loot_table\rennet.json'), $rennetTable, $utf8)

# ---------------------------------------------------------------- rennet from livestock
$rennetModifier = @'
{
  "type": "neoforge:add_table",
  "conditions": [
    {
      "condition": "minecraft:any_of",
      "terms": [
        {
          "condition": "neoforge:loot_table_id",
          "loot_table_id": "minecraft:entities/cow"
        },
        {
          "condition": "neoforge:loot_table_id",
          "loot_table_id": "minecraft:entities/sheep"
        }
      ]
    },
    {
      "condition": "minecraft:killed_by_player"
    },
    {
      "condition": "minecraft:random_chance_with_enchanted_bonus",
      "enchantment": "minecraft:looting",
      "unenchanted_chance": 0.5,
      "enchanted_chance": {
        "type": "minecraft:linear",
        "base": 0.5,
        "per_level_above_first": 0.15
      }
    }
  ],
  "table": "tfc_food_port:rennet"
}
'@
New-Dir (Join-Path $data 'loot_modifiers')
[System.IO.File]::WriteAllText((Join-Path $data 'loot_modifiers\add_rennet_from_livestock.json'), $rennetModifier, $utf8)

# ---------------------------------------------------------------- fresh seaweed from ocean plants
$seaweedTable = @'
{
  "type": "minecraft:block",
  "pools": [
    {
      "bonus_rolls": 0.0,
      "rolls": 1.0,
      "entries": [
        {
          "type": "minecraft:item",
          "name": "tfc_food_port:food/fresh_seaweed"
        }
      ]
    }
  ],
  "random_sequence": "tfc_food_port:fresh_seaweed"
}
'@
[System.IO.File]::WriteAllText((Join-Path $data 'loot_table\fresh_seaweed.json'), $seaweedTable, $utf8)

$seaweedModifier = @'
{
  "type": "neoforge:add_table",
  "conditions": [
    {
      "condition": "minecraft:any_of",
      "terms": [
        {
          "condition": "neoforge:loot_table_id",
          "loot_table_id": "minecraft:blocks/seagrass"
        },
        {
          "condition": "neoforge:loot_table_id",
          "loot_table_id": "minecraft:blocks/kelp"
        },
        {
          "condition": "neoforge:loot_table_id",
          "loot_table_id": "minecraft:blocks/kelp_plant"
        }
      ]
    },
    {
      "condition": "minecraft:random_chance",
      "chance": 0.5
    }
  ],
  "table": "tfc_food_port:fresh_seaweed"
}
'@
[System.IO.File]::WriteAllText((Join-Path $data 'loot_modifiers\add_fresh_seaweed_from_ocean_plants.json'), $seaweedModifier, $utf8)

Write-Output 'loot tables/modifiers written:'
Get-ChildItem $data -Recurse -File -Filter *.json | Where-Object { $_.FullName -match 'loot_(table|modifiers)' } | ForEach-Object { Write-Output ('  ' + $_.FullName.Replace($data + '\', '')) }
