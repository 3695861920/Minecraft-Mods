$ErrorActionPreference = 'Stop'

# Generates every recipe for the port in the 26.1.2 format:
#   - ingredients are plain strings ("minecraft:melon" or "#c:crops/rice")
#   - results are {"count": n, "id": "..."}
#   - farmersdelight:cutting results are [{"item": {...}}] and need a knife tool block
# Pure ASCII script; all identifiers are ASCII.

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
$recipeDir = Join-Path $moduleDir 'src\main\resources\data\tfc_food_port\recipe'
if (Test-Path $recipeDir) { Remove-Item $recipeDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $recipeDir | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)

$ns = 'tfc_food_port'
$count = 0
# NOTE: never write "$ns:..." inside an interpolated string - PowerShell reads "$ns:" as a scope/drive
# qualifier and quietly substitutes an empty string. Always use "${ns}:".

function Write-Recipe([string]$path, [string]$json) {
  $full = Join-Path $script:recipeDir ($path -replace '/', '\')
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($full, $json, $script:utf8)
  $script:count++
}

# ---------------------------------------------------------------- load time conditions
# A recipe can carry "neoforge:conditions", which NeoForge evaluates WHILE THE DATAPACK LOADS and drops the recipe
# if it does not hold. That is the mechanism behind the multi mod support: the same processing step is emitted up to
# three times - once for Farmer's Delight's machines, once for Kaleidoscope Cookery's, once using only vanilla
# blocks - and the conditions decide which of them actually exist in the world.
#
# This is deliberately a datapack level thing rather than something the mod checks in code. Recipes are data, so a
# condition is evaluated by the same loader that reads the file, at the stage where the set of recipes is being
# built. Doing it in code would mean registering three recipe sets and deleting two of them after the fact.
#
# The field is "modid" for mod_loaded and "value" for not, and the condition's own name goes in "type" - these are
# in NeoForge's source at common/conditions/ModLoadedCondition and NotCondition.
$condFD = '    { "type": "neoforge:mod_loaded", "modid": "farmersdelight" }'
$condKC = '    { "type": "neoforge:mod_loaded", "modid": "kaleidoscope_cookery" }'
# Only when NEITHER mod is present. Two conditions in the list are ANDed, so listing both negations is enough to
# express "no Farmer's Delight and no Kaleidoscope Cookery".
$condVanilla = @'
    { "type": "neoforge:not", "value": { "type": "neoforge:mod_loaded", "modid": "farmersdelight" } },
    { "type": "neoforge:not", "value": { "type": "neoforge:mod_loaded", "modid": "kaleidoscope_cookery" } }
'@

# Inserts a conditions block as the first key of a recipe object. The recipe builders below all return a string that
# starts with "{", so the block is spliced in right after that brace; JSON does not care about key order.
function With-Conditions([string]$json, [string]$conditions) {
  $i = $json.IndexOf('{')
  if ($i -lt 0) { throw 'recipe json does not start with an object' }
  return $json.Substring(0, $i + 1) + "`n  `"neoforge:conditions`": [`n" + $conditions + "`n  ]," + $json.Substring($i + 1)
}

# Writes one recipe variant. $conditions is the block above; pass an empty string for an unconditional recipe.
function Write-Conditional([string]$path, [string]$json, [string]$conditions, [string]$mustContain) {
  if ($conditions -ne '') { $json = With-Conditions $json $conditions }
  if ($mustContain -and $json -notmatch [regex]::Escape($mustContain)) {
    throw ("generated recipe lost '" + $mustContain + "': " + $path)
  }
  Write-Recipe $path $json
}

# ---------------------------------------------------------------- helpers
$knifeTool = @'
    {
      "neoforge:ingredient_type": "neoforge:compound",
      "children": [
        {
          "neoforge:ingredient_type": "farmersdelight:item_ability",
          "action": "knife_dig"
        },
        "#c:tools/knife"
      ]
    }
'@

function Cutting([string]$ingredient, [string]$result, [int]$resultCount) {
  return @"
{
  "type": "farmersdelight:cutting",
  "ingredients": [
    "$ingredient"
  ],
  "result": [
    {
      "item": {
        "count": $resultCount,
        "id": "$result"
      }
    }
  ],
  "tool": $knifeTool
}
"@
}

function Smelting([string]$ingredient, [string]$result) {
  return @"
{
  "type": "minecraft:smelting",
  "category": "food",
  "cookingtime": 200,
  "experience": 0.35,
  "ingredient": "$ingredient",
  "result": {
    "count": 1,
    "id": "$result"
  }
}
"@
}

function Smoking([string]$ingredient, [string]$result) {
  return @"
{
  "type": "minecraft:smoking",
  "category": "food",
  "cookingtime": 100,
  "experience": 0.35,
  "ingredient": "$ingredient",
  "result": {
    "count": 1,
    "id": "$result"
  }
}
"@
}

function Cooking([string[]]$ingredients, [string]$result, [int]$resultCount, [int]$time, [string]$container) {
  $list = ($ingredients | ForEach-Object { '    "' + $_ + '"' }) -join ",`n"
  $containerBlock = ''
  if ($container -ne '') {
    $containerBlock = "  `"container`": {`n    `"count`": 1,`n    `"id`": `"$container`"`n  },`n"
  }
  return @"
{
  "type": "farmersdelight:cooking",
$containerBlock  "experience": 0.35,
  "cookingtime": $time,
  "ingredients": [
$list
  ],
  "result": {
    "count": $resultCount,
    "id": "$result"
  }
}
"@
}

function Shapeless([string[]]$ingredients, [string]$result, [int]$resultCount) {
  $list = ($ingredients | ForEach-Object { '    "' + $_ + '"' }) -join ",`n"
  return @"
{
  "type": "minecraft:crafting_shapeless",
  "category": "misc",
  "ingredients": [
$list
  ],
  "result": {
    "count": $resultCount,
    "id": "$result"
  }
}
"@
}

function ShapelessGroup([string]$group, [string[]]$ingredients, [string]$result, [int]$resultCount) {
  $list = ($ingredients | ForEach-Object { '    "' + $_ + '"' }) -join ",`n"
  return @"
{
  "type": "minecraft:crafting_shapeless",
  "category": "misc",
  "group": "$group",
  "ingredients": [
$list
  ],
  "result": {
    "count": $resultCount,
    "id": "$result"
  }
}
"@
}

# ---------------------------------------------------------------- Kaleidoscope Cookery builders
# Field names and shapes are taken from Kaleidoscope Cookery's own recipe files in its jar, which is the ground
# truth for the format:
#   millstone       { "ingredient": <ingredient>, "result": { "count": n, "id": "..." } }
#   chopping_board  { "cut_count": n, "ingredient": <ingredient>, "model_id": "...", "result": { ... } }
#   pot             { "carrier": <ingredient>, "ingredients": [ ... ], "result": { ... } }
# `carrier` is that mod's equivalent of Farmer's Delight's container: the item the finished dish is served in.
# `model_id` on the chopping board only picks which in world model is shown while cutting, so it is left out.

function KcMillstone([string]$ingredient, [string]$result, [int]$resultCount) {
  return @"
{
  "type": "kaleidoscope_cookery:millstone",
  "ingredient": "$ingredient",
  "result": {
    "count": $resultCount,
    "id": "$result"
  }
}
"@
}

function KcChoppingBoard([string]$ingredient, [string]$result, [int]$resultCount, [int]$cutCount) {
  return @"
{
  "type": "kaleidoscope_cookery:chopping_board",
  "cut_count": $cutCount,
  "ingredient": "$ingredient",
  "result": {
    "count": $resultCount,
    "id": "$result"
  }
}
"@
}

function KcPot([string[]]$ingredients, [string]$result, [int]$resultCount, [string]$carrier) {
  $list = ($ingredients | ForEach-Object { '    "' + $_ + '"' }) -join ",`n"
  $carrierBlock = ''
  if ($carrier -ne '') { $carrierBlock = "  `"carrier`": `"$carrier`",`n" }
  return @"
{
  "type": "kaleidoscope_cookery:pot",
$carrierBlock  "ingredients": [
$list
  ],
  "result": {
    "count": $resultCount,
    "id": "$result"
  }
}
"@
}

$grains = @('barley', 'oat', 'rye', 'wheat', 'rice', 'maize')

# ================================================================ grain chain
# crop -> grain -> flour -> dough -> bread
#
# Each processing step that needs a mod machine is emitted three times, and the conditions decide which survives
# loading:
#   <name>           Farmer's Delight  (cutting board / cooking pot)   - active when Farmer's Delight is present
#   <name>_kc        Kaleidoscope Cookery (chopping board / millstone / pot) - when that mod is present
#   <name>_vanilla   vanilla only      (crafting / furnace)            - only when NEITHER mod is present
# With both mods installed the Farmer's Delight and Kaleidoscope Cookery variants are both live, which is intended:
# they are different machines, so the player can use whichever they built.
foreach ($g in $grains) {
  $crop = "${ns}" + ':food/' + $g
  $grain = "${ns}" + ':food/' + $g + '_grain'
  $flour = "${ns}" + ':food/' + $g + '_flour'
  $dough = "${ns}" + ':food/' + $g + '_dough'
  $bread = "${ns}" + ':food/' + $g + '_bread'

  # knife the harvested crop into grain
  Write-Conditional "food/$g`_grain.json" (Cutting $crop $grain 1) $condFD $grain
  Write-Conditional "food/$g`_grain_kc.json" (KcChoppingBoard $crop $grain 1 3) $condKC $grain
  Write-Conditional "food/$g`_grain_vanilla.json" (Shapeless @($crop) $grain 1) $condVanilla $grain

  # grind the grain into flour
  Write-Conditional "food/$g`_flour.json" (Cutting $grain $flour 1) $condFD $flour
  Write-Conditional "food/$g`_flour_kc.json" (KcMillstone $grain $flour 1) $condKC $flour
  Write-Conditional "food/$g`_flour_vanilla.json" (Shapeless @($grain) $flour 1) $condVanilla $flour

  # flour + water -> dough. The crafting recipe is the port's own vanilla path and is left unconditional: it is not
  # a stand in for a mod machine, and a water bucket is a legitimate way to make dough. The two pot variants are the
  # mod machine paths and stay conditional.
  Write-Recipe "food/$g`_dough_from_crafting.json" (ShapelessGroup 'tfc_food_port_dough' @($flour, 'minecraft:water_bucket') $dough 1)
  Write-Conditional "food/$g`_dough_from_cooking.json" (Cooking @($flour, $flour) $dough 1 100 '') $condFD $dough
  Write-Conditional "food/$g`_dough_from_pot_kc.json" (KcPot @($flour, $flour) $dough 1 '') $condKC $dough
  # (throwing the flour into water is handled in code, see WaterConvertibleItem)
  # bake the dough
  Write-Recipe "food/$g`_bread_from_smelting.json" (Smelting $dough $bread)
  Write-Recipe "food/$g`_bread_from_smoking.json" (Smoking $dough $bread)

  # bread sandwiches
  $sandwich = "$ns" + ':food/' + $g + '_bread_sandwich'
  $jamSandwich = "$ns" + ':food/' + $g + '_bread_jam_sandwich'
  Write-Recipe "food/$g`_bread_sandwich.json" (ShapelessGroup 'tfc_food_port_sandwich' @($bread, '#c:foods/vegetable', '#c:foods/cooked_meat') $sandwich 1)
  # any jam works, matching TFC's "tfc:foods/jam" tag
  Write-Recipe "food/$g`_bread_jam_sandwich.json" (ShapelessGroup 'tfc_food_port_jam_sandwich' @($bread, "#$ns`:jams", '#c:foods/cooked_meat') $jamSandwich 1)
}

# cooked rice, in whichever pot is available; with neither mod it is simply cooked like any other food
Write-Conditional 'food/cooked_rice.json' (Cooking @(("${ns}" + ':food/rice')) ("${ns}" + ':food/cooked_rice') 1 100 '') $condFD 'cooked_rice'
Write-Conditional 'food/cooked_rice_kc.json' (KcPot @(("${ns}" + ':food/rice')) ("${ns}" + ':food/cooked_rice') 1 '') $condKC 'cooked_rice'
Write-Conditional 'food/cooked_rice_vanilla_from_smelting.json' (Smelting ("${ns}" + ':food/rice') ("${ns}" + ':food/cooked_rice')) $condVanilla 'cooked_rice'
Write-Conditional 'food/cooked_rice_vanilla_from_smoking.json' (Smoking ("${ns}" + ':food/rice') ("${ns}" + ':food/cooked_rice')) $condVanilla 'cooked_rice'

# ================================================================ vegetables and tubers
Write-Recipe 'food/baked_potato_from_smelting.json' (Smelting ("${ns}" + ':food/potato') ("${ns}" + ':food/baked_potato'))
Write-Recipe 'food/baked_potato_from_smoking.json' (Smoking ("${ns}" + ':food/potato') ("${ns}" + ':food/baked_potato'))
Write-Recipe 'food/cooked_cassava_from_smelting.json' (Smelting ("${ns}" + ':food/cassava') ("${ns}" + ':food/cooked_cassava'))
Write-Recipe 'food/cooked_cassava_from_smoking.json' (Smoking ("${ns}" + ':food/cassava') ("${ns}" + ':food/cooked_cassava'))
Write-Recipe 'food/cooked_lentil_from_smelting.json' (Smelting ("${ns}" + ':food/lentil') ("${ns}" + ':food/cooked_lentil'))
Write-Recipe 'food/cooked_lentil_from_smoking.json' (Smoking ("${ns}" + ':food/lentil') ("${ns}" + ':food/cooked_lentil'))

# melon and pumpkin are cut into pieces. A knife on a board, a board in Kaleidoscope Cookery, or a knife-free
# shapeless craft when neither mod is installed.
Write-Conditional 'food/melon_slice.json' (Cutting 'minecraft:melon' ("${ns}" + ':food/melon_slice') 4) $condFD 'melon_slice'
Write-Conditional 'food/melon_slice_kc.json' (KcChoppingBoard 'minecraft:melon' ("${ns}" + ':food/melon_slice') 4 4) $condKC 'melon_slice'
Write-Conditional 'food/melon_slice_vanilla.json' (Shapeless @('minecraft:melon') ("${ns}" + ':food/melon_slice') 4) $condVanilla 'melon_slice'
Write-Conditional 'food/pumpkin_chunks.json' (Cutting 'minecraft:pumpkin' ("${ns}" + ':food/pumpkin_chunks') 4) $condFD 'pumpkin_chunks'
Write-Conditional 'food/pumpkin_chunks_kc.json' (KcChoppingBoard 'minecraft:pumpkin' ("${ns}" + ':food/pumpkin_chunks') 4 4) $condKC 'pumpkin_chunks'
Write-Conditional 'food/pumpkin_chunks_vanilla.json' (Shapeless @('minecraft:pumpkin') ("${ns}" + ':food/pumpkin_chunks') 4) $condVanilla 'pumpkin_chunks'

# eggs. A boiled egg is a pot recipe when a pot exists, and an ordinary cooked food when none does.
Write-Recipe 'food/cooked_egg_from_smelting.json' (Smelting 'minecraft:egg' ("${ns}" + ':food/cooked_egg'))
Write-Recipe 'food/cooked_egg_from_smoking.json' (Smoking 'minecraft:egg' ("${ns}" + ':food/cooked_egg'))
Write-Conditional 'food/boiled_egg.json' (Cooking @('minecraft:egg') ("${ns}" + ':food/boiled_egg') 1 200 '') $condFD 'boiled_egg'
Write-Conditional 'food/boiled_egg_kc.json' (KcPot @('minecraft:egg') ("${ns}" + ':food/boiled_egg') 1 '') $condKC 'boiled_egg'
Write-Conditional 'food/boiled_egg_vanilla_from_smelting.json' (Smelting 'minecraft:egg' ("${ns}" + ':food/boiled_egg')) $condVanilla 'boiled_egg'
Write-Conditional 'food/boiled_egg_vanilla_from_smoking.json' (Smoking 'minecraft:egg' ("${ns}" + ':food/boiled_egg')) $condVanilla 'boiled_egg'

# ================================================================ seaweed
Write-Recipe 'food/dried_seaweed_from_smelting.json' (Smelting ("${ns}" + ':food/fresh_seaweed') ("${ns}" + ':food/dried_seaweed'))
Write-Recipe 'food/dried_seaweed_from_smoking.json' (Smoking ("${ns}" + ':food/fresh_seaweed') ("${ns}" + ':food/dried_seaweed'))

# ================================================================ cheese
# milk + rennet -> curd (cooking pot) -> cheese (furnace / smoker)
# No "container" here: a milk bucket already leaves an empty bucket as its crafting remainder, and the pot puts
# ingredient remainders back on its own. The curd is a solid item, so it needs no bowl or bucket to be taken out
# with either.
Write-Conditional 'food/cheese_curd.json' (Cooking @('minecraft:milk_bucket', ("${ns}" + ':rennet')) ("${ns}" + ':food/cheese_curd') 1 600 '') $condFD 'cheese_curd'
Write-Conditional 'food/cheese_curd_kc.json' (KcPot @('minecraft:milk_bucket', ("${ns}" + ':rennet')) ("${ns}" + ':food/cheese_curd') 1 '') $condKC 'cheese_curd'
Write-Conditional 'food/cheese_curd_vanilla.json' (Shapeless @('minecraft:milk_bucket', ("${ns}" + ':rennet')) ("${ns}" + ':food/cheese_curd') 1) $condVanilla 'cheese_curd'
Write-Recipe 'food/cheese_from_smelting.json' (Smelting ("${ns}" + ':food/cheese_curd') ("${ns}" + ':food/cheese'))
Write-Recipe 'food/cheese_from_smoking.json' (Smoking ("${ns}" + ':food/cheese_curd') ("${ns}" + ':food/cheese'))

# ================================================================ jams
# Two of the fruit plus a sweetener, cooked in whichever pot is available. With neither mod installed a jam is made
# in the crafting grid instead, which is the only way left to make one.
#
# A jam has no container - it comes out of the pot as the jar itself - so Kaleidoscope Cookery's "carrier" is left
# out here. That is also what keeps a jam distinguishable from the fruit soup below.
$jamFruits = @(
  'blackberry', 'raspberry', 'blueberry', 'elderberry', 'snowberry', 'bunchberry', 'gooseberry',
  'cloudberry', 'strawberry', 'wintergreen_berry', 'cranberry',
  'banana', 'cherry', 'green_apple', 'red_apple', 'lemon', 'olive', 'orange', 'peach', 'plum',
  'melon_slice'
)
foreach ($f in $jamFruits) {
  $fruit = "${ns}" + ':food/' + $f
  $jam = "${ns}" + ':food/jam/' + $f
  Write-Conditional "food/jam/$f.json" (Cooking @($fruit, $fruit, 'minecraft:sugar') $jam 2 500 '') $condFD $jam
  Write-Conditional "food/jam/$f`_kc.json" (KcPot @($fruit, $fruit, 'minecraft:sugar') $jam 2 '') $condKC $jam
  Write-Conditional "food/jam/$f`_vanilla.json" (Shapeless @($fruit, $fruit, 'minecraft:sugar') $jam 2) $condVanilla $jam
}
# peanut butter uses the peanut instead of sugar. The vanilla variant does the same, so the fallback keeps the
# flavour rather than quietly becoming a different recipe.
$peanut = "${ns}" + ':food/peanut'
$peanutJam = "${ns}" + ':food/jam/peanut'
Write-Conditional 'food/jam/peanut.json' (Cooking @($peanut, $peanut, 'minecraft:sugar') $peanutJam 2 500 '') $condFD $peanutJam
Write-Conditional 'food/jam/peanut_kc.json' (KcPot @($peanut, $peanut, 'minecraft:sugar') $peanutJam 2 '') $condKC $peanutJam
Write-Conditional 'food/jam/peanut_vanilla.json' (Shapeless @($peanut, $peanut, 'minecraft:sugar') $peanutJam 2) $condVanilla $peanutJam

# ================================================================ soups (pot, served in a bowl)
# Two constraints shape these ingredient lists:
#
# 1. A soup must be DISTINGUISHABLE from a jam. Fruit soup used to be exactly "two fruit + sugar", which is also
#    exactly a jam recipe - so putting two strawberries and sugar in the pot matched both, and whichever recipe the
#    manager happened to return won. That is a real ambiguity, not a cosmetic one: the player could not choose.
#    Fruit soup therefore takes a water bucket as well, which also makes it read as a soup rather than a syrup.
#
# 2. A declared "container" must be the thing the eater gets back. Farmer's Delight's cooking pot takes the meal out
#    with the container the recipe names, and the CONSUMABLE component's use-remainder is what the player receives
#    when eating, so the two have to agree or a bowl would vanish. (An earlier comment here claimed Farmer's Delight
#    validates this at runtime and rejects a mismatch - it does not; the message comes from Farmer's Delight's own
#    game test, which asserts the convention over Farmer's Delight recipes only. The convention is still the right
#    design, so it is followed.)
#
# Ingredients that leave a crafting remainder are fine as long as the container is not declared to match them. A
# water bucket is the case in point: it leaves a bucket behind, and the cooking pot ejects ingredient remainders
# when the meal finishes, so the bucket comes back on its own. Declaring "container": "minecraft:bucket" as well
# would hand the player two buckets, which is why only the soup's bowl is declared.
$soups = @{
  'grain_soup'      = @('#c:crops/grain', '#c:foods/vegetable', '#c:foods/vegetable')
  'fruit_soup'      = @('#c:foods/fruit', '#c:foods/fruit', 'minecraft:sugar', 'minecraft:water_bucket')
  'vegetables_soup' = @('#c:foods/vegetable', '#c:foods/vegetable', '#c:foods/vegetable')
  'protein_soup'    = @('#c:foods/cooked_meat', '#c:foods/cooked_meat', '#c:foods/vegetable')
  'dairy_soup'      = @(("${ns}" + ':food/cheese'), '#c:foods/vegetable', '#c:crops/grain')
}
foreach ($k in ($soups.Keys | Sort-Object)) {
  $soupId = "${ns}" + ':food/' + $k
  # a bowl is the container in every machine: Farmer's Delight calls it "container", Kaleidoscope Cookery "carrier"
  Write-Conditional "food/$k.json" (Cooking $soups[$k] $soupId 1 600 'minecraft:bowl') $condFD $soupId
  Write-Conditional "food/$k`_kc.json" (KcPot $soups[$k] $soupId 1 'minecraft:bowl') $condKC $soupId
  # vanilla fallback: the same ingredients shaken up with a bowl in the crafting grid. The water bucket needed by
  # the fruit soup is fine here too - vanilla crafting returns a bucket for it on its own.
  Write-Conditional "food/$k`_vanilla.json" (Shapeless (@('minecraft:bowl') + $soups[$k]) $soupId 1) $condVanilla $soupId
}

# ================================================================ salads (crafting, served in a bowl)
$salads = @{
  'grain_salad'      = @('#c:crops/grain', '#c:foods/vegetable', '#c:foods/vegetable')
  'fruit_salad'      = @('#c:foods/fruit', '#c:foods/fruit', 'minecraft:sugar')
  'vegetables_salad' = @('#c:foods/vegetable', '#c:foods/vegetable', '#c:foods/vegetable')
  'protein_salad'    = @('#c:foods/cooked_meat', '#c:foods/vegetable', '#c:foods/vegetable')
  'dairy_salad'      = @(("${ns}" + ':food/cheese'), '#c:foods/vegetable', '#c:foods/vegetable')
}
foreach ($k in ($salads.Keys | Sort-Object)) {
  Write-Recipe "food/$k.json" (Shapeless (@('minecraft:bowl') + $salads[$k]) ("${ns}" + ':food/' + $k) 1)
}

# ================================================================ jams, part 2: the two golden apple ones
# A magical apple makes a magical jam. Two apples plus a sweetener, the same shape as every other jam, so a golden
# apple from an apple tree can be turned into something worth eight mooncakes rather than one snack.
foreach ($pair in @(@('gold_apple', 'minecraft:golden_apple'), @('enchanted_gold_apple', 'minecraft:enchanted_golden_apple'))) {
  $name = $pair[0]; $apple = $pair[1]
  $jamId = "${ns}" + ':food/jam/' + $name
  Write-Conditional "food/jam/$name.json" (Cooking @($apple, $apple, 'minecraft:sugar') $jamId 2 500 '') $condFD $name
  Write-Conditional "food/jam/$name`_kc.json" (KcPot @($apple, $apple, 'minecraft:sugar') $jamId 2 '') $condKC $name
  Write-Conditional "food/jam/$name`_vanilla.json" (Shapeless @($apple, $apple, 'minecraft:sugar') $jamId 2) $condVanilla $name
}

# ================================================================ mooncakes
# Mooncakes are made in two steps, which is what makes them feel baked rather than assembled:
#
#   1. a jar of jam and some dough are pressed into EIGHT RAW mooncakes
#   2. each raw one is baked in a furnace (or a smoker) into the real thing
#
# So the flavour is chosen before the pastry is baked, and there are 24 raw items to match the 24 cakes - one raw
# item could not be used here, because a single furnace input can only have one output and the filling decides the
# result.
#
# The dough is #c:foods/dough, which the port's own six doughs and Farmer's Delight's wheat dough all belong to, so
# a player can bake mooncakes from whichever grain they farmed.
function Raw-Mooncake([string]$jam, [string]$raw) {
  return @"
{
  "type": "minecraft:crafting_shapeless",
  "category": "misc",
  "group": "${ns}_raw_mooncake",
  "ingredients": [
    "$jam",
    "#c:foods/dough",
    "#c:foods/dough",
    "#c:foods/dough",
    "#c:foods/dough"
  ],
  "result": {
    "count": 8,
    "id": "$raw"
  }
}
"@
}

$mooncakeFruits = @(
  'blackberry', 'raspberry', 'blueberry', 'elderberry', 'snowberry', 'bunchberry', 'gooseberry',
  'cloudberry', 'strawberry', 'wintergreen_berry', 'cranberry',
  'banana', 'cherry', 'green_apple', 'red_apple', 'lemon', 'olive', 'orange', 'peach', 'plum',
  'melon_slice', 'peanut', 'gold_apple', 'enchanted_gold_apple'
)

foreach ($f in $mooncakeFruits) {
  $jam = "${ns}" + ':food/jam/' + $f
  $raw = "${ns}" + ':food/raw_mooncake/' + $f
  $cake = "${ns}" + ':food/mooncake/' + $f

  Write-Recipe "food/raw_mooncake/$f.json" (Raw-Mooncake $jam $raw)
  # baking it: a furnace is the slow way and a smoker the fast one, exactly like bread and the other baked goods
  Write-Recipe "food/mooncake/$f`_from_smelting.json" (Smelting $raw $cake)
  Write-Recipe "food/mooncake/$f`_from_smoking.json" (Smoking $raw $cake)
}

# ================================================================ the barrel block itself
# NOTE: this script clears the whole recipe directory at the top, so every recipe - including the
# block recipes - has to be emitted here. Forgetting one silently deletes it from the built jar.
$barrelRecipe = @"
{
  "type": "minecraft:crafting_shaped",
  "category": "misc",
  "group": "${ns}_barrel",
  "key": {
    "S": "#minecraft:slabs"
  },
  "pattern": [
    "SSS",
    "S S",
    "SSS"
  ],
  "result": {
    "count": 1,
    "id": "${ns}:barrel"
  }
}
"@
if ($barrelRecipe -notmatch [regex]::Escape($ns + ':barrel')) { throw 'barrel recipe lost its namespace' }
Write-Recipe 'barrel.json' $barrelRecipe

# ================================================================ rennet is not craftable, it drops from livestock
# fresh seaweed is not craftable either, it comes from vanilla ocean plants (see gen-loot.ps1)

# ================================================================ common item tags
# Adding the ported items to NeoForge's common tags lets other mods (including Farmer's Delight itself) use them.
$tagDir = Join-Path $moduleDir 'src\main\resources\data\c\tags\item'
function Write-Tag([string]$path, [string[]]$values) {
  # NOTE: the '.json' has to be appended here. Without it every file landed on disk as "foods/dough" with no
  # extension, and Minecraft only loads *.json, so all eight tags were silently empty - which is why
  # #c:foods/dough resolved to Farmer's Delight's tag alone and this mod's own dough could not be used in any
  # recipe, and why the port's fruits and vegetables were ignored by its own soup and salad recipes.
  $full = (Join-Path $tagDir ($path -replace '/', '\')) + '.json'
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $list = ($values | ForEach-Object { '    "' + $_ + '"' }) -join ",`n"
  $json = "{`n  `"values`": [`n$list`n  ]`n}`n"
  [System.IO.File]::WriteAllText($full, $json, $script:utf8)
  $script:count++
}

# Drop the extension-less files the bug above left behind, so a stale copy cannot shadow the real tag.
$staleTags = 0
Get-ChildItem $tagDir -Recurse -File | Where-Object { $_.Extension -ne '.json' } | ForEach-Object {
  Remove-Item $_.FullName -Force; $staleTags++
}
if ($staleTags -gt 0) { Write-Output ("removed extension-less tag files: " + $staleTags) }

function FoodIds([string[]]$names) { return ($names | ForEach-Object { "$ns" + ':food/' + $_ }) }

Write-Tag 'foods/dough' (FoodIds @('barley_dough', 'oat_dough', 'rye_dough', 'wheat_dough', 'rice_dough', 'maize_dough'))
Write-Tag 'foods/bread' (FoodIds @('barley_bread', 'oat_bread', 'rye_bread', 'wheat_bread', 'rice_bread', 'maize_bread'))
Write-Tag 'foods/berry' (FoodIds @('blackberry', 'raspberry', 'blueberry', 'elderberry', 'snowberry', 'bunchberry', 'gooseberry', 'cloudberry', 'strawberry', 'wintergreen_berry', 'cranberry'))
Write-Tag 'foods/cooked_egg' (FoodIds @('cooked_egg', 'boiled_egg'))
Write-Tag 'foods/soup' (FoodIds @('grain_soup', 'fruit_soup', 'vegetables_soup', 'protein_soup', 'dairy_soup'))
Write-Tag 'foods/vegetable' (FoodIds @('beet', 'cabbage', 'carrot', 'garlic', 'green_bean', 'green_bell_pepper', 'red_bell_pepper', 'yellow_bell_pepper', 'onion', 'potato', 'baked_potato', 'soybean', 'squash', 'tomato', 'cassava', 'cooked_cassava', 'lentil', 'cooked_lentil', 'radish', 'pumpkin_chunks'))
Write-Tag 'foods/fruit' (FoodIds @('blackberry', 'raspberry', 'blueberry', 'elderberry', 'snowberry', 'bunchberry', 'gooseberry', 'cloudberry', 'strawberry', 'wintergreen_berry', 'cranberry', 'banana', 'cherry', 'green_apple', 'red_apple', 'lemon', 'olive', 'orange', 'peach', 'plum', 'melon_slice'))
Write-Tag 'crops/grain' (FoodIds @('barley', 'oat', 'rye', 'wheat', 'rice', 'maize'))

# Farmer's Delight splits dough into c:foods/dough (the umbrella) and c:foods/dough/wheat (wheat dough only), and
# resolves the umbrella to a single entry pointing at the wheat sub-tag. Listing the port's six doughs in the
# umbrella is what makes ANY of them valid wherever #c:foods/dough is asked for - the mooncake recipe included.
Write-Tag 'foods/dough/wheat' (FoodIds @('wheat_dough'))

# our own jam tag, so any jam can be used in a jam sandwich (TFC used a "tfc:foods/jam" tag too).
# The two golden apple jams are listed explicitly: they are jams, but not fruit, so they are not in $jamFruits.
$ownTagDir = Join-Path $moduleDir 'src\main\resources\data\tfc_food_port\tags\item'
$jamIds = ($jamFruits + @('peanut', 'gold_apple', 'enchanted_gold_apple')) | ForEach-Object { "$ns" + ':food/jam/' + $_ }
$full = Join-Path $ownTagDir 'jams.json'
New-Item -ItemType Directory -Force -Path $ownTagDir | Out-Null
$jamList = ($jamIds | ForEach-Object { '    "' + $_ + '"' }) -join ",`n"
[System.IO.File]::WriteAllText($full, "{`n  `"values`": [`n$jamList`n  ]`n}`n", $utf8)
$count++

Write-Output ("recipes written: " + $count)
Write-Output ("dir: " + $recipeDir)
