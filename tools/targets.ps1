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
}

# The default target. Deliberately the newest, because that is what a bare `gen-*.ps1` has always meant.
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
