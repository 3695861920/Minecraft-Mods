$ErrorActionPreference = 'Stop'
$root = 'C:\Users\36958\Documents\AI'
$jar = (Get-ChildItem -Path (Join-Path $root '*\*TerraFirmaCraft*.jar') -File | Select-Object -First 1).FullName
$tools = Join-Path (Split-Path $jar) 'tools'
$out = Join-Path $tools 'src'
New-Item -ItemType Directory -Force -Path $out | Out-Null
Write-Output ("Decompiling: " + $jar)
Write-Output ("Output: " + $out)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
& java -Xmx2G -jar (Join-Path $tools 'vineflower.jar') -dgs=1 -hdc=0 -jvn=1 -inner=1 -var=1 $jar $out
Write-Output ("Exit: " + $LASTEXITCODE + "  elapsed: " + $sw.Elapsed.TotalSeconds + "s")
