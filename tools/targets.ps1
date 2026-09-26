$ErrorActionPreference = 'Stop'

# The set of targets this repository generates resources for, and where each target's Gradle module lives.
#
# The generators in tools/ write into a module's src/main/resources. That path used to be the repository root, back
# when there was one target; now it is per target, so the location is looked up here instead of being hardcoded in
# nine separate scripts. Adding a target means adding one line below.
#
# The target is chosen with the TFC_TARGET environment variable and defaults to the one that already exists, so every
# existing command keeps working unchanged. It is an environment variable rather than a parameter because the scripts
# are also invoked from the CI workflow and from run-*.cmd wrappers, and threading an argument through all of them
# would be more places to get wrong.
# Pure ASCII.

$TFC_TARGET_MODULES = [ordered]@{
    'neoforge-26.1.2' = 'versions/neoforge-26.1.2'
    'neoforge-1.21.1' = 'versions/neoforge-1.21.1'
}

# The default target. Deliberately a specific one rather than "the newest", because a bare `gen-*.ps1` should do
# exactly what it did before this repository became multi target, and changing which module it writes into would be
# a silent change in behaviour.
$TFC_DEFAULT_TARGET = 'neoforge-26.1.2'

function Get-TargetName {
    $name = $env:TFC_TARGET
    if ([string]::IsNullOrWhiteSpace($name)) { return $TFC_DEFAULT_TARGET }
    $name = $name.Trim()
    if (-not $TFC_TARGET_MODULES.Contains($name)) {
        $known = ($TFC_TARGET_MODULES.Keys -join ', ')
        throw ("unknown target '" + $name + "'. Known targets: " + $known + "   (set the TFC_TARGET environment variable)")
    }
    return $name
}

# Resolves a target name to that module's directory, checking that it actually exists - a typo in the table above
# would otherwise show up much later as a pile of files written into a directory nothing reads.
function Get-TargetModuleDir([string]$repoRoot, [string]$name) {
    if ([string]::IsNullOrWhiteSpace($name)) { $name = Get-TargetName }
    if (-not $TFC_TARGET_MODULES.Contains($name)) {
        $known = ($TFC_TARGET_MODULES.Keys -join ', ')
        throw ("unknown target '" + $name + "'. Known targets: " + $known)
    }
    $dir = Join-Path $repoRoot ($TFC_TARGET_MODULES[$name] -replace '/', '\')
    if (-not (Test-Path $dir)) { throw ("target '" + $name + "' maps to " + $dir + ", which does not exist") }
    return $dir
}

# Convenience for the generators: the module directory for the currently selected target.
function Get-ModuleDir([string]$repoRoot) {
    return Get-TargetModuleDir $repoRoot (Get-TargetName)
}

# ---------------------------------------------------------------- per target capabilities
#
# What differs between two Minecraft versions is rarely "the version number" - it is whether a particular data
# format exists. Asking a version number ("is it at least 1.21.2?") spreads that knowledge across every generator
# and gets it wrong the moment a third target lands in the middle. So the generators ask about capabilities, and
# this table is the single place that knows which version has which.
#
#   itemDefinitions  the assets/<ns>/items/** layer, which arrived after 1.21.1. Where absent, an item's model is
#                    resolved straight from models/item/** and the definition files must not be written at all -
#                    writing them would be harmless but would add 210 files that nothing reads.
#   ingredientStyle  'string' for the shorthand "minecraft:melon" / "#c:crops/rice". 'object' for the older
#                    {"item": "minecraft:melon"} / {"tag": "c:crops/rice"}. Verified from Ingredient's codec on each
#                    version rather than assumed: 1.21.1's codec is either(list of Value, single Value) and Value is
#                    an object with an item or tag key, so a bare string is rejected.
#   farmModRecipes   whether the Farmer's Delight and Kaleidoscope Cookery recipe formats for this target have been
#                    confirmed against those mods' own jars. False means the generator refuses to emit them, so an
#                    unverified format becomes a loud failure instead of a recipe that looks plausible and does not
#                    load.
$TFC_TARGET_CAPS = @{
    'neoforge-26.1.2' = @{
        itemDefinitions = $true
        ingredientStyle = 'string'
        farmModRecipes  = $true
    }
    'neoforge-1.21.1' = @{
        itemDefinitions = $false
        ingredientStyle = 'object'
        farmModRecipes  = $false
    }
}

function Get-TargetCaps([string]$name) {
    if ([string]::IsNullOrWhiteSpace($name)) { $name = Get-TargetName }
    if (-not $TFC_TARGET_CAPS.Contains($name)) {
        throw ("no capability entry for target '" + $name + "'. Add one to " + '$' + "TFC_TARGET_CAPS in tools/targets.ps1")
    }
    return $TFC_TARGET_CAPS[$name]
}

# Convenience for the generators: the capability table for the currently selected target.
function Get-ModuleCaps([string]$name) {
    return Get-TargetCaps $name
}

# ---------------------------------------------------------------- writing generated files
#
# Every generator writes through this, because getting line endings wrong here has a consequence that is easy to
# miss and expensive to chase: the built jar stops matching the jar CI ships.
#
# The mechanism: the .ps1 scripts are pinned to CRLF by .gitattributes (that is what cmd.exe and PowerShell expect),
# so a here-string in a script contains CRLF, and the string a generator assembles carries CRLF into the file. The
# resource files themselves are pinned to LF. Git hides the difference - it normalises on add, so the committed
# bytes are LF either way - but Gradle copies the WORKING TREE bytes into the jar, so a Windows build produced a jar
# whose 521 JSON entries each differed from the released one by exactly one byte per line.
#
# That silently broke the one check this repository relies on: "rebuild locally and compare the fingerprint to the
# release". It reported a difference for every build and therefore told us nothing. Normalising here makes the
# generated bytes identical on every platform, so the fingerprint means something again.
#
# UTF-8 without a BOM, deliberately: a BOM is three bytes at the start of a JSON file, and Minecraft's parsers
# reject it. There is a fix-bom.ps1 in this folder from the time that bit us.
$script:TFC_Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-TextFile([string]$path, [string]$text) {
    $dir = Split-Path $path -Parent

    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    $text = $text -replace "`r`n", "`n"
    $text = $text -replace "`r", "`n"

    [System.IO.File]::WriteAllText($path, $text, $script:TFC_Utf8NoBom)
}

