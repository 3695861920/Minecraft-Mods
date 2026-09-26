$ErrorActionPreference = 'Stop'
$root = 'C:\Users\36958\Documents\AI'
$tools = (Get-ChildItem -Path (Join-Path $root '*\tools') -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'vineflower.jar') } | Select-Object -First 1).FullName
$vf = Join-Path $tools 'vineflower.jar'
$jobs = @(
  @{ pattern = '*FarmersDelight*.jar'; out = 'src-fd' },
  @{ pattern = '*kaleidoscope*.jar';   out = 'src-kc' }
)
foreach ($j in $jobs) {
  $jar = (Get-ChildItem -Path (Join-Path $root ('*\' + $j.pattern)) -File | Select-Object -First 1).FullName
  if (-not $jar) { Write-Output ('skip ' + $j.pattern); continue }
  $out = Join-Path $tools $j.out
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  Write-Output ('Decompiling ' + $jar)
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  & java -Xmx2G -jar $vf -dgs=1 -hdc=0 -jvn=1 -inner=1 $jar $out | Out-Null
  Write-Output ('  exit=' + $LASTEXITCODE + '  ' + [math]::Round($sw.Elapsed.TotalSeconds, 1) + 's  files=' + (Get-ChildItem $out -Recurse -Filter *.java).Count)
}
