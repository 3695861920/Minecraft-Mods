$ErrorActionPreference = 'Stop'
$base = 'C:\Users\36958\Documents\AI'
$ex = (Get-ChildItem -Path (Join-Path $base '*\tools\extract') -Directory | Select-Object -First 1).FullName
$out = Join-Path (Split-Path $ex) 'out'
New-Item -ItemType Directory -Force -Path $out | Out-Null

# 1) food definitions
$foodDir = Join-Path $ex 'data\tfc\tfc\food'
$lines = New-Object System.Collections.Generic.List[string]
foreach ($f in Get-ChildItem $foodDir -Recurse -File -Filter *.json) {
  $j = [System.IO.File]::ReadAllText($f.FullName) | ConvertFrom-Json
  $ing = ''
  if ($j.ingredient.item) { $ing = $j.ingredient.item } elseif ($j.ingredient.tag) { $ing = '#' + $j.ingredient.tag }
  $hunger = if ($j.hunger -ne $null) { $j.hunger } else { '' }
  $sat = if ($j.saturation -ne $null) { $j.saturation } else { '' }
  $cats = @()
  foreach ($p in $j.PSObject.Properties) { if ($p.Name -in @('grain','protein','dairy','fruit','vegetables')) { $cats += ($p.Name + '=' + $p.Value) } }
  $edible = if ($j.edible -eq $false) { 'NOT_EDIBLE' } else { '' }
  $rel = $f.FullName.Substring($foodDir.Length + 1)
  $lines.Add(($rel -replace '\\','/') + "`t" + $ing + "`t" + $hunger + "`t" + $sat + "`t" + ($cats -join ' ') + "`t" + $edible)
}
[System.IO.File]::WriteAllLines((Join-Path $out 'foods.tsv'), $lines, [System.Text.Encoding]::UTF8)

# 2) crop loot tables
$cropDir = Join-Path $ex 'data\tfc\loot_table\blocks\crop'
$lines2 = New-Object System.Collections.Generic.List[string]
foreach ($f in Get-ChildItem $cropDir -File -Filter *.json) {
  $t = [System.IO.File]::ReadAllText($f.FullName)
  $names = [regex]::Matches($t, '"name":"((?:tfc|minecraft):[a-z_/]+)"') | ForEach-Object { $_.Groups[1].Value }
  $lines2.Add($f.BaseName + "`t" + (($names | Sort-Object -Unique) -join ', '))
}
[System.IO.File]::WriteAllLines((Join-Path $out 'crops.tsv'), $lines2, [System.Text.Encoding]::UTF8)

# 3) lang keys of interest
$lang = Join-Path $ex 'assets\tfc\lang\zh_cn.json'
$j = [System.IO.File]::ReadAllText($lang, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$lines3 = New-Object System.Collections.Generic.List[string]
foreach ($p in $j.PSObject.Properties) {
  if ($p.Name -match '^(item|block|fluid|entity)\.tfc\.') { $lines3.Add($p.Name + "`t" + $p.Value) }
}
[System.IO.File]::WriteAllLines((Join-Path $out 'lang_zh.tsv'), $lines3, [System.Text.Encoding]::UTF8)

Write-Output ("foods: " + $lines.Count + "  crops: " + $lines2.Count + "  lang: " + $lines3.Count)
Write-Output ("out: " + $out)
