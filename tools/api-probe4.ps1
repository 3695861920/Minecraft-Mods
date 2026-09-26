$nf = 'C:\Users\36958\Documents\AI\group\tools\nf-src'
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$nf = Join-Path $root 'tools\nf-src'

function Pick([string]$pattern, [string]$grep, [int]$n) {
  $f = Get-ChildItem $nf -Recurse -File -Filter *.java | Where-Object { $_.FullName -like $pattern } | Select-Object -First 1
  if (-not $f) { Write-Output ('MISSING ' + $pattern); return }
  Write-Output ('===== ' + $f.Name)
  Select-String -Path $f.FullName -Pattern $grep | Select-Object -First $n | ForEach-Object { Write-Output ('  ' + $_.LineNumber.ToString().PadLeft(5) + ': ' + $_.Line.Trim()) }
}

Pick '*\transfer\ResourceHandler.java' 'int insert|insert\(|int extract|extract\(' 12
Pick '*\transfer\fluid\FluidResource.java' 'static FluidResource of|public static FluidResource' 6
Pick '*\transfer\transaction\Transaction.java' 'static Transaction openRoot|openRoot\(' 6
Write-Output ''
Write-Output '=== GameTestHelper: succeed / runAfterDelay / assertTrue ==='
Add-Type -AssemblyName System.IO.Compression.FileSystem
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($src)
$e = $z.Entries | Where-Object { $_.FullName -eq 'net/minecraft/gametest/framework/GameTestHelper.java' } | Select-Object -First 1
$sr = New-Object System.IO.StreamReader($e.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
$lines | Select-String -Pattern 'public void succeed\(|public void runAfterDelay|public void assertTrue|public void assertFalse' | ForEach-Object { Write-Output ('  ' + $_.LineNumber.ToString().PadLeft(5) + ': ' + $_.Line.Trim()) }
$z.Dispose()
