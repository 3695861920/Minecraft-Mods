$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Works out the native pixel grid of the supplied mooncake template.
#
# The file is 1254x1254 but it is pixel art that has been scaled up: the "big pixels" are clearly visible. If the
# scale factor is an integer, the native art can be recovered exactly and resampled cleanly instead of being
# blurred by a naive downscale. This finds the run lengths of identical colour along several rows; for pixel art
# every colour change lands on a multiple of the scale factor, so the most common small run length is it.
# Pure ASCII.

$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$src = Join-Path $root 'mooncake.png'
if (-not (Test-Path $src)) { throw "no mooncake.png at $src" }

$bmp = New-Object System.Drawing.Bitmap($src)
$w = $bmp.Width; $h = $bmp.Height
$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
$d = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$stride = $d.Stride
$buf = New-Object byte[] ($stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($d.Scan0, $buf, 0, $buf.Length)
$bmp.UnlockBits($d)
$bmp.Dispose()

Write-Output ("image: " + $w + " x " + $h)
Write-Output ("1254 factorises as 2*3*11*19 -> integer upscales: 11,19,22,33,38,57,66,114,209,418,627")

# All horizontal colour-change positions on a row, then the histogram of the gaps between them.
function Show-RowGaps([int]$y) {
    $changes = New-Object System.Collections.Generic.List[int]
    for ($x = 1; $x -lt $w; $x++) {
        $o = $y * $stride + $x * 4
        $oC = $y * $stride + ($x - 1) * 4
        if ($buf[$o] -ne $buf[$oC] -or $buf[$o + 1] -ne $buf[$oC + 1] -or $buf[$o + 2] -ne $buf[$oC + 2] -or $buf[$o + 3] -ne $buf[$oC + 3]) {
            $changes.Add($x)
        }
    }
    $hist = @{}
    for ($i = 1; $i -lt $changes.Count; $i++) {
        $gap = $changes[$i] - $changes[$i - 1]
        if ($hist.ContainsKey($gap)) { $hist[$gap]++ } else { $hist[$gap] = 1 }
    }
    $top = $hist.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 6
    Write-Output ("  row y=" + $y.ToString().PadLeft(4) + "  changes=" + $changes.Count.ToString().PadLeft(4) + "  gaps: " + (($top | ForEach-Object { $_.Key.ToString() + "x" + $_.Value }) -join ', '))
}

for ($y = 250; $y -lt $h; $y += 125) { Show-RowGaps $y }

# A whole-image check: assume scale S, then every SxS cell should be a single flat colour. Count how many cells
# are NOT flat for each candidate scale; the true scale gives the smallest violation rate.
Write-Output ''
Write-Output 'cell flatness test (lower = more likely the true scale):'
foreach ($s in @(6, 11, 19, 22, 33, 38, 57, 66, 418, 627)) {
    if ($w % $s -ne 0 -or $h % $s -ne 0) { Write-Output ("  scale " + $s.ToString().PadLeft(3) + "  does not divide " + $w); continue }
    $nonFlat = 0; $total = 0
    for ($cy = 0; $cy -lt ($h / $s); $cy++) {
        for ($cx = 0; $cx -lt ($w / $s); $cx++) {
            $total++
            $x0 = $cx * $s; $y0 = $cy * $s
            $o0 = $y0 * $stride + $x0 * 4
            $r = $buf[$o0]; $g = $buf[$o0 + 1]; $b = $buf[$o0 + 2]; $a = $buf[$o0 + 3]
            $flat = $true
            for ($yy = $y0; $yy -lt $y0 + $s -and $flat; $yy++) {
                for ($xx = $x0; $xx -lt $x0 + $s; $xx++) {
                    $o = $yy * $stride + $xx * 4
                    if ([Math]::Abs($buf[$o] - $r) -gt 1 -or [Math]::Abs($buf[$o + 1] - $g) -gt 1 -or [Math]::Abs($buf[$o + 2] - $b) -gt 1) { $flat = $false; break }
                }
            }
            if (-not $flat) { $nonFlat++ }
        }
    }
    Write-Output ("  scale " + $s.ToString().PadLeft(3) + "  ->  " + $s.ToString() + "x" + $s + " native, non-flat cells " + $nonFlat + " / " + $total + "  (" + [Math]::Round(100.0 * $nonFlat / $total, 2) + "%)")
}

# opaque bounding box, so the art can be centred on a square canvas
$minx = $w; $maxx = -1; $miny = $h; $maxy = -1
for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        if ($buf[$y * $stride + $x * 4 + 3] -gt 8) {
            if ($x -lt $minx) { $minx = $x }
            if ($x -gt $maxx) { $maxx = $x }
            if ($y -lt $miny) { $miny = $y }
            if ($y -gt $maxy) { $maxy = $y }
        }
    }
}
Write-Output ''
Write-Output ("opaque bbox: x " + $minx + ".." + $maxx + "  y " + $miny + ".." + $maxy + "  (" + ($maxx - $minx + 1) + " x " + ($maxy - $miny + 1) + ")")

# luminance spread of the opaque art, for building the recolour ramp
$lums = New-Object System.Collections.Generic.List[double]
for ($y = $miny; $y -le $maxy; $y += 3) {
    for ($x = $minx; $x -le $maxx; $x += 3) {
        $o = $y * $stride + $x * 4
        if ($buf[$o + 3] -lt 128) { continue }
        $lums.Add((0.299 * $buf[$o + 2] + 0.587 * $buf[$o + 1] + 0.114 * $buf[$o]) / 255.0)
    }
}
$sorted = $lums | Sort-Object
$n = $sorted.Count
Write-Output ("luminance over art: min " + [Math]::Round($sorted[0], 3) + "  p10 " + [Math]::Round($sorted[[int]($n * 0.10)], 3) + "  median " + [Math]::Round($sorted[[int]($n * 0.5)], 3) + "  p90 " + [Math]::Round($sorted[[int]($n * 0.90)], 3) + "  max " + [Math]::Round($sorted[$n - 1], 3))
