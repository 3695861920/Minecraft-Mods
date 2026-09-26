Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($src)

function Show([string]$entry, [string]$pattern, [int]$ctx) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $entry } | Select-Object -First 1
  if (-not $e) { Write-Output ('MISSING ' + $entry); return }
  $sr = New-Object System.IO.StreamReader($e.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
  Write-Output ('===== ' + $entry)
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $pattern) {
      for ($j = [Math]::Max(0, $i - 1); $j -le [Math]::Min($lines.Count - 1, $i + $ctx); $j++) {
        Write-Output ('  ' + ($j + 1).ToString().PadLeft(5) + ': ' + $lines[$j])
      }
      Write-Output '  ---'
    }
  }
}

Show 'net/minecraft/world/level/block/CropBlock.java' 'canSurvive|mayPlaceOn|hasSufficientLight|getBaseSeedId|isRandomlyTicking|getGrowthSpeed|getMaxAge' 4
Show 'net/minecraft/gametest/framework/GameTestHelper.java' 'makeMockPlayer|public Player|public ItemStack|public void setBlock|assertTrue\(' 1
$z.Dispose()
