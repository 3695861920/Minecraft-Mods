$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing

# Inspect the art this port needs to reuse: the vanilla cocoa pod (to be recoloured into a banana bunch) and the
# jam textures (whose average colour will tint the mooncakes). Pure ASCII.

$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$root = Split-Path $jar -Parent
$mcJar = Get-ChildItem "$env:USERPROFILE\.gradle\caches\neoformruntime\artifacts\minecraft_*_client.jar" -File |
    Where-Object { $_.Name -match '26\.1\.2' } | Select-Object -First 1
$work = Join-Path $root 'tools\extract\tex'
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Get-Member-Png($zip, [string]$entryName, [string]$outName) {
    $e = $zip.Entries | Where-Object { $_.FullName -eq $entryName } | Select-Object -First 1
    if (-not $e) { return $null }
    $dest = Join-Path $work $outName
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true)
    return $dest
}

function Show-Png([string]$path, [string]$label) {
    if (-not $path) { Write-Output ("MISSING " + $label); return }
    $bmp = New-Object System.Drawing.Bitmap($path)
    Write-Output ("--- " + $label + "  " + $bmp.Width + "x" + $bmp.Height)
    $hist = @{}
    for ($y = 0; $y -lt $bmp.Height; $y++) {
        for ($x = 0; $x -lt $bmp.Width; $x++) {
            $c = $bmp.GetPixel($x, $y)
            if ($c.A -eq 0) { continue }
            $key = ('{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B)
            if ($hist.ContainsKey($key)) { $hist[$key]++ } else { $hist[$key] = 1 }
        }
    }
    $total = 0
    foreach ($k in $hist.Keys) { $total += $hist[$k] }
    Write-Output ("    opaque pixels: " + $total + "   distinct colours: " + $hist.Count)
    $top = $hist.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 12
    foreach ($t in $top) { Write-Output ("      #" + $t.Key + "  x" + $t.Value) }
    $bmp.Dispose()
}

$mc = [System.IO.Compression.ZipFile]::OpenRead($mcJar.FullName)
foreach ($s in @(0, 1, 2)) {
    $p = Get-Member-Png $mc ("assets/minecraft/textures/block/cocoa_stage$s.png") "cocoa_stage$s.png"
    Show-Png $p "minecraft cocoa_stage$s"
}
Show-Png (Get-Member-Png $mc 'assets/minecraft/textures/block/jungle_leaves.png' 'jungle_leaves.png') 'minecraft jungle_leaves'
$mc.Dispose()

$tfc = [System.IO.Compression.ZipFile]::OpenRead($jar)
foreach ($f in @('banana', 'blackberry', 'strawberry', 'orange', 'cherry', 'olive', 'peanut', 'melon_slice')) {
    $p = Get-Member-Png $tfc ("assets/tfc/textures/item/jar/$f.png") "jam_$f.png"
    Show-Png $p ("jam " + $f)
}
$tfc.Dispose()
