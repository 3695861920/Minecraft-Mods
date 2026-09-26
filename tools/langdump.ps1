$ErrorActionPreference = 'Stop'
$base = 'C:\Users\36958\Documents\AI'
$ex = (Get-ChildItem -Path (Join-Path $base '*\tools\extract') -Directory | Select-Object -First 1).FullName
$out = Join-Path (Split-Path $ex) 'out'
$lang = Join-Path $ex 'assets\tfc\lang\zh_cn.json'
$en = Join-Path $ex 'assets\tfc\lang\en_us.json'
$jz = [System.IO.File]::ReadAllText($lang, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$je = [System.IO.File]::ReadAllText($en, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

$map = New-Object 'System.Collections.Generic.Dictionary[string,string]'
foreach ($p in $je.PSObject.Properties) { $map[$p.Name] = [string]$p.Value }

$pat = '^item\.tfc\.(food|seeds|jar|powder|bucket)\.|^block\.tfc\.(crop|barrel|fluid|plant)|^item\.tfc\.barrel'
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("KEY`tZH`tEN")
foreach ($p in $jz.PSObject.Properties) {
  if ($p.Name -match $pat) {
    $ev = ''
    if ($map.ContainsKey($p.Name)) { $ev = $map[$p.Name] }
    $lines.Add($p.Name + "`t" + [string]$p.Value + "`t" + $ev)
  }
}
[System.IO.File]::WriteAllLines((Join-Path $out 'lang_filtered.tsv'), $lines, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ($lines.Count.ToString() + " lines written")
