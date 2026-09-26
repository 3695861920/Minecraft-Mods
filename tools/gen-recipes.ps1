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
$root = Split-Path $jar -Parent
$recipeDir = Join-Path $root 'src\main\resources\data\tfc_food_port\recipe'
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

$grains = @('barley', 'oat', 'rye', 'wheat', 'rice', 'maize')

# ================================================================ grain chain
# crop -> grain -> flour -> dough -> bread
foreach ($g in $grains) {
  $crop = "${ns}" + ':food/' + $g
  $grain = "${ns}" + ':food/' + $g + '_grain'
  $flour = "${ns}" + ':food/' + $g + '_flour'
  $dough = "${ns}" + ':food/' + $g + '_dough'
  $bread = "${ns}" + ':food/' + $g + '_bread'

  # knife the harvested crop into grain
  Write-Recipe "food/$g`_grain.json" (Cutting $crop $grain 1)
  # grind the grain into flour on the cutting board
  Write-Recipe "food/$g`_flour.json" (Cutting $grain $flour 1)
  # flour + water -> dough, three ways
  Write-Recipe "food/$g`_dough_from_crafting.json" (ShapelessGroup 'tfc_food_port_dough' @($flour, 'minecraft:water_bucket') $dough 1)
  Write-Recipe "food/$g`_dough_from_cooking.json" (Cooking @($flour, $flour) $dough 1 100 '')
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

# cooked rice from the cooking pot
Write-Recipe 'food/cooked_rice.json' (Cooking @(("${ns}" + ':food/rice')) ("${ns}" + ':food/cooked_rice') 1 100 '')

# ================================================================ vegetables and tubers
Write-Recipe 'food/baked_potato_from_smelting.json' (Smelting ("${ns}" + ':food/potato') ("${ns}" + ':food/baked_potato'))
Write-Recipe 'food/baked_potato_from_smoking.json' (Smoking ("${ns}" + ':food/potato') ("${ns}" + ':food/baked_potato'))
Write-Recipe 'food/cooked_cassava_from_smelting.json' (Smelting ("${ns}" + ':food/cassava') ("${ns}" + ':food/cooked_cassava'))
Write-Recipe 'food/cooked_cassava_from_smoking.json' (Smoking ("${ns}" + ':food/cassava') ("${ns}" + ':food/cooked_cassava'))
Write-Recipe 'food/cooked_lentil_from_smelting.json' (Smelting ("${ns}" + ':food/lentil') ("${ns}" + ':food/cooked_lentil'))
Write-Recipe 'food/cooked_lentil_from_smoking.json' (Smoking ("${ns}" + ':food/lentil') ("${ns}" + ':food/cooked_lentil'))

# melon and pumpkin are cut into pieces
Write-Recipe 'food/melon_slice.json' (Cutting 'minecraft:melon' ("${ns}" + ':food/melon_slice') 4)
Write-Recipe 'food/pumpkin_chunks.json' (Cutting 'minecraft:pumpkin' ("${ns}" + ':food/pumpkin_chunks') 4)

# ================================================================ eggs
Write-Recipe 'food/cooked_egg_from_smelting.json' (Smelting 'minecraft:egg' ("${ns}" + ':food/cooked_egg'))
Write-Recipe 'food/cooked_egg_from_smoking.json' (Smoking 'minecraft:egg' ("${ns}" + ':food/cooked_egg'))
Write-Recipe 'food/boiled_egg.json' (Cooking @('minecraft:egg') ("${ns}" + ':food/boiled_egg') 1 200 '')

# ================================================================ seaweed
Write-Recipe 'food/dried_seaweed_from_smelting.json' (Smelting ("${ns}" + ':food/fresh_seaweed') ("${ns}" + ':food/dried_seaweed'))
Write-Recipe 'food/dried_seaweed_from_smoking.json' (Smoking ("${ns}" + ':food/fresh_seaweed') ("${ns}" + ':food/dried_seaweed'))

# ================================================================ cheese
# milk + rennet -> curd (cooking pot) -> cheese (furnace / smoker)
# No "container" here: a milk bucket already leaves an empty bucket as its crafting remainder, and Farmer's Delight
# rejects pot recipes whose declared container does not match that remainder ("container does not match the consumed
# remainder"). The curd is a solid item, so it needs no bowl or bucket to be taken out with either.
Write-Recipe 'food/cheese_curd.json' (Cooking @('minecraft:milk_bucket', ("${ns}" + ':rennet')) ("${ns}" + ':food/cheese_curd') 1 600 '')
Write-Recipe 'food/cheese_from_smelting.json' (Smelting ("${ns}" + ':food/cheese_curd') ("${ns}" + ':food/cheese'))
Write-Recipe 'food/cheese_from_smoking.json' (Smoking ("${ns}" + ':food/cheese_curd') ("${ns}" + ':food/cheese'))

# ================================================================ jams
# two of the fruit plus a sweetener, cooked in the pot
$jamFruits = @(
  'blackberry', 'raspberry', 'blueberry', 'elderberry', 'snowberry', 'bunchberry', 'gooseberry',
  'cloudberry', 'strawberry', 'wintergreen_berry', 'cranberry',
  'banana', 'cherry', 'green_apple', 'red_apple', 'lemon', 'olive', 'orange', 'peach', 'plum',
  'melon_slice'
)
foreach ($f in $jamFruits) {
  $fruit = "${ns}" + ':food/' + $f
  Write-Recipe "food/jam/$f.json" (Cooking @($fruit, $fruit, 'minecraft:sugar') ("${ns}" + ':food/jam/' + $f) 2 500 '')
}
# peanut butter uses the peanut instead of sugar
Write-Recipe 'food/jam/peanut.json' (Cooking @(("${ns}" + ':food/peanut'), ("${ns}" + ':food/peanut'), 'minecraft:sugar') ("${ns}" + ':food/jam/peanut') 2 500 '')

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
  Write-Recipe "food/$k.json" (Cooking $soups[$k] ("${ns}" + ':food/' + $k) 1 600 'minecraft:bowl')
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
Write-Recipe 'food/jam/gold_apple.json' (Cooking @('minecraft:golden_apple', 'minecraft:golden_apple', 'minecraft:sugar') ("${ns}" + ':food/jam/gold_apple') 2 500 '')
Write-Recipe 'food/jam/enchanted_gold_apple.json' (Cooking @('minecraft:enchanted_golden_apple', 'minecraft:enchanted_golden_apple', 'minecraft:sugar') ("${ns}" + ':food/jam/enchanted_gold_apple') 2 500 '')

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
$tagDir = Join-Path $root 'src\main\resources\data\c\tags\item'
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
$ownTagDir = Join-Path $root 'src\main\resources\data\tfc_food_port\tags\item'
$jamIds = ($jamFruits + @('peanut', 'gold_apple', 'enchanted_gold_apple')) | ForEach-Object { "$ns" + ':food/jam/' + $_ }
$full = Join-Path $ownTagDir 'jams.json'
New-Item -ItemType Directory -Force -Path $ownTagDir | Out-Null
$jamList = ($jamIds | ForEach-Object { '    "' + $_ + '"' }) -join ",`n"
[System.IO.File]::WriteAllText($full, "{`n  `"values`": [`n$jamList`n  ]`n}`n", $utf8)
$count++

Write-Output ("recipes written: " + $count)
Write-Output ("dir: " + $recipeDir)
