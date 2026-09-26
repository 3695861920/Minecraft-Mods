Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($src)

function Pick([string]$pattern, [string]$grep, [int]$n) {
  $e = $z.Entries | Where-Object { $_.FullName -like $pattern } | Select-Object -First 1
  if (-not $e) { Write-Output ('MISSING ' + $pattern); return }
  $sr = New-Object System.IO.StreamReader($e.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
  Write-Output ('===== ' + $e.FullName)
  $lines | Select-String -Pattern $grep | Select-Object -First $n | ForEach-Object { Write-Output ('  ' + $_.LineNumber.ToString().PadLeft(5) + ': ' + $_.Line.Trim()) }
}

Pick 'net/minecraft/world/level/block/CropBlock.java' 'public static final|IntegerProperty AGE|MAX_AGE' 8
Pick 'net/neoforged/neoforge/transfer/ResourceHandler.java' 'int insert|ResourceStack<.*> insert|int extract|ResourceStack<.*> extract|default int' 14
Pick 'net/neoforged/neoforge/transfer/fluid/FluidResource.java' 'static FluidResource of|public static' 6
Pick 'net/neoforged/neoforge/transfer/transaction/Transaction.java' 'static Transaction openRoot|public static' 6
Pick 'net/minecraft/gametest/framework/GameTestHelper.java' 'public void runAfterDelay|public ServerLevel getLevel|public void succeed' 5
$z.Dispose()
