$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$root = Split-Path $jar -Parent
$tools = Join-Path $root 'tools'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$rows = [System.IO.File]::ReadAllLines((Join-Path $tools 'fruitbush-lang.tsv'), [System.Text.Encoding]::UTF8)
$keys = @{}
foreach ($r in $rows) {
  if ([string]::IsNullOrWhiteSpace($r)) { continue }
  $keys[$r.TrimStart([char]0xFEFF).Split("`t")[0].Trim()] = 1
}

$extraPath = Join-Path $tools 'extra-lang.tsv'
$kept = New-Object System.Collections.Generic.List[string]
$removed = 0
foreach ($line in [System.IO.File]::ReadAllLines($extraPath, [System.Text.Encoding]::UTF8)) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  $k = $line.TrimStart([char]0xFEFF).Split("`t")[0].Trim()
  if ($keys.ContainsKey($k)) { $removed++ } else { $kept.Add($line) }
}
foreach ($r in $rows) { if (-not [string]::IsNullOrWhiteSpace($r)) { $kept.Add($r.TrimStart([char]0xFEFF)) } }
[System.IO.File]::WriteAllLines($extraPath, $kept, $utf8)
Write-Output ("replaced rows: " + $removed + "   appended: " + $rows.Count)
