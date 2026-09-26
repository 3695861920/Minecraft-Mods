$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$tools = Join-Path $root 'tools'

Write-Output '=== extra-lang.tsv rows mentioning sapling ==='
$extra = [System.IO.File]::ReadAllLines((Join-Path $tools 'extra-lang.tsv'), [System.Text.Encoding]::UTF8)
$extra | Where-Object { $_ -match 'sapling' } | ForEach-Object { '  ' + $_ }
Write-Output ('  total extra-lang rows: ' + $extra.Count)

Write-Output ''
Write-Output '=== lang files: any sapling keys? ==='
$lang = Join-Path $root 'src\main\resources\assets\tfc_food_port\lang'
foreach ($f in @('en_us.json', 'zh_cn.json')) {
  $t = [System.IO.File]::ReadAllText((Join-Path $lang $f), [System.Text.Encoding]::UTF8)
  $c = ([regex]::Matches($t, 'sapling')).Count
  Write-Output ("  $f : 'sapling' occurrences = $c")
}

Write-Output ''
Add-Type -AssemblyName System.IO.Compression.FileSystem
$tfcJar = (Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($tfcJar)
Write-Output '=== TFC banana: all textures ==='
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/textures/block/fruit_tree/banana*' } | ForEach-Object { '  ' + $_.FullName.Split('/')[-1] }
Write-Output '=== TFC banana: all models ==='
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/models/block/plant/banana*' } | ForEach-Object { '  ' + $_.FullName.Split('/')[-1] }
Write-Output '=== TFC banana: blockstates ==='
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/blockstates/plant/banana*' } | ForEach-Object { '  ' + $_.FullName.Split('/')[-1] }

function Dump([string]$p) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $p } | Select-Object -First 1
  if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output ('===== ' + $p); Write-Output $sr.ReadToEnd(); $sr.Close() }
}
Dump 'assets/tfc/models/block/plant/banana_trunk_2.json'
Dump 'assets/tfc/models/block/plant/banana_trunk_2_fruiting.json'
Dump 'assets/tfc/blockstates/plant/banana.json'
$z.Dispose()
