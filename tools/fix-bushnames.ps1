$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$root = Split-Path $jar -Parent
$tools = Join-Path $root 'tools'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# drop the bush rows that fell back to the item name, so gen-berries.ps1 can add the proper TFC bush names
$extraPath = Join-Path $tools 'extra-lang.tsv'
$kept = New-Object System.Collections.Generic.List[string]
$removed = 0
foreach ($line in [System.IO.File]::ReadAllLines($extraPath, [System.Text.Encoding]::UTF8)) {
  if ($line -match '^block\.tfc_food_port\.plant\.') { $removed++ }
  elseif (-not [string]::IsNullOrWhiteSpace($line)) { $kept.Add($line) }
}
[System.IO.File]::WriteAllLines($extraPath, $kept, $utf8)
Write-Output ("removed stale bush name rows: " + $removed)
