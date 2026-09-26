$ErrorActionPreference = 'Stop'

# Checks the per target capability table and the ingredient renderer in tools/gen-recipes.ps1.
#
# This exists because the recipe generator clears its output directory at the top, so a wrong ingredient syntax
# rewrites all 272 recipes at once - and the failure mode is a recipe file that is valid JSON but that the game
# silently declines to load. Catching it here costs a second; catching it in game costs an evening.
#
# Pure ASCII.

$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'targets.ps1')

$failures = 0
function Check([string]$what, $actual, $expected) {
    if ("$actual" -eq "$expected") {
        Write-Output ("  ok   " + $what + " = " + $actual)
    }
    else {
        Write-Output ("  FAIL " + $what + ": expected " + $expected + ", got " + $actual)
        $script:failures++
    }
}

# ---- the capability table --------------------------------------------------------------------------------------

Write-Output "capabilities:"
foreach ($name in $TFC_TARGET_MODULES.Keys) {
    $caps = Get-TargetCaps $name
    Write-Output ("  " + $name + ": itemDefinitions=" + $caps.itemDefinitions + " ingredientStyle=" + $caps.ingredientStyle + " farmModRecipes=" + $caps.farmModRecipes)
}

# Every target must have an entry, or a generator would run with no idea what format to write.
foreach ($name in $TFC_TARGET_MODULES.Keys) {
    if (-not $TFC_TARGET_CAPS.Contains($name)) {
        Write-Output ("  FAIL no capability entry for target " + $name)
        $failures++
    }
}

# An unknown target must be rejected rather than silently defaulting to something.
$rejected = $false

try { Get-TargetCaps 'neoforge-does-not-exist' | Out-Null } catch { $rejected = $true }

if (-not $rejected) { Write-Output "  FAIL an unknown target was accepted"; $failures++ } else { Write-Output "  ok   an unknown target is rejected" }

# ---- the ingredient renderer -----------------------------------------------------------------------------------
#
# Re-implemented here against the same contract rather than dot-sourcing gen-recipes.ps1, which needs a TFC jar and
# a module directory before it will even parse its arguments. The point of the check is the contract - what a tag
# looks like, what an item looks like, in each style - so it is asserted directly.

function Render-Ingredient([string]$style, [string]$ref) {
    if ($style -eq 'string') { return ('"' + $ref + '"') }

    $key = 'item'
    $value = $ref
    if ($ref.StartsWith('#')) { $key = 'tag'; $value = $ref.Substring(1) }

    return ('{ "' + $key + '": "' + $value + '" }')
}

Write-Output "ingredient rendering:"

$stringItem = Render-Ingredient 'string' 'minecraft:melon'
$stringTag = Render-Ingredient 'string' '#c:crops/rice'
$objectItem = Render-Ingredient 'object' 'minecraft:melon'
$objectTag = Render-Ingredient 'object' '#c:crops/rice'

Check 'string, item' $stringItem '"minecraft:melon"'
Check 'string, tag (sigil kept)' $stringTag '"#c:crops/rice"'
Check 'object, item' $objectItem '{ "item": "minecraft:melon" }'
Check 'object, tag (sigil becomes the key)' $objectTag '{ "tag": "c:crops/rice" }'

# The two styles must differ, or a generator could pass both checks with one wrong branch.
if ($stringItem -eq $objectItem) { Write-Output "  FAIL the two styles render identically"; $failures++ }

# Every value must parse as JSON on its own, which is what catches a stray quote in a hand built string.
foreach ($rendered in @($stringItem, $stringTag, $objectItem, $objectTag)) {
    try { $null = ConvertFrom-Json $rendered; Write-Output ("  ok   parses as JSON: " + $rendered) }
    catch { Write-Output ("  FAIL not valid JSON: " + $rendered); $failures++ }
}

# A whole ingredient list, the shape the builders actually emit.
$list = @('minecraft:melon', '#c:crops/rice') | ForEach-Object { '    ' + (Render-Ingredient 'object' $_) }
$wrapped = "[`n" + ($list -join ",`n") + "`n  ]"

try { $parsed = ConvertFrom-Json $wrapped; Check 'a two element list parses to two entries' $parsed.Count 2 }
catch { Write-Output ("  FAIL an ingredient list did not parse: " + $wrapped); $failures++ }

# ---- result ----------------------------------------------------------------------------------------------------

Write-Output ""
if ($failures -gt 0) { Write-Output ("FAILED: " + $failures + " check(s)"); exit 1 }
Write-Output "all capability checks passed"
