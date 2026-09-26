$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing

# Draws the two pieces of art this port cannot take from TerraFirmaCraft.
#
# 1. Banana bunch - a RECOLOUR of vanilla's cocoa pod. The bunch is rendered by vanilla's cocoa models
#    (minecraft:block/cocoa_stage0..2), so reusing those exact images at the exact size guarantees the geometry and
#    shading line up; only the palette is replaced, by projecting each pixel's relative brightness onto a banana
#    ramp (green while unripe, yellow when ripe). Nothing is redrawn by hand, so the pod keeps its vanilla shape.
#
# 2. Mooncakes - the template in the repository root (mooncake.png) is one 1254x1254 pixel-art render of a
#    mooncake. Every cake uses that EXACT art or nothing: the template is reduced once to a 32x32 grid of brightness
#    and coverage, then each cake maps that brightness through its own colour ramp. So all 24 cakes share the
#    template's shape, lattice pattern and shading and differ only in hue, and nothing is redrawn by hand.
#
#    The fruit colours are READ OUT OF the jam textures rather than invented: a jam image is a jar (identical art
#    in all 22 files) with the fruit inside, so the colours that appear in EVERY jam are the jar, and each jam's
#    most common remaining colour is its fruit.
#
# Everything here is generated locally from the template, so there is no third-party art and no watermark anywhere.
# Magnified contact sheets are written to tools/out/mooncake-preview-32.png and -16.png for eyeballing.
# Pure ASCII script.

# Locate the TerraFirmaCraft jar without hardcoding where this machine keeps it. These scripts live in
# <root>/tools and the jar is expected in the project root, so the path is derived rather than globbed. The previous
# version searched an absolute path, which meant the generators could only run on one machine - and could not run in
# CI at all, where the release workflow downloads the jar into exactly this root.
$root = Split-Path $PSScriptRoot -Parent
$tfcJarFile = Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $tfcJarFile) { throw ('no TerraFirmaCraft jar in ' + $root + ': these generators read TFC textures and data out of it') }
$jar = $tfcJarFile.FullName
$root = Split-Path $jar -Parent
$assets = Join-Path $root 'src\main\resources\assets\tfc_food_port'
$texItem = Join-Path $assets 'textures\item'
$texBlock = Join-Path $assets 'textures\block\plant'
$jamDir = Join-Path $texItem 'food\jam'
$outDir = Join-Path $root 'tools\out'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$mcJar = Get-ChildItem "$env:USERPROFILE\.gradle\caches\neoformruntime\artifacts\minecraft_*_client.jar" -File |
    Where-Object { $_.Name -match '26\.1\.2' } | Select-Object -First 1
if (-not $mcJar) { throw 'could not find the 26.1.2 client jar for the cocoa textures' }

$fruits = @(
    'blackberry', 'raspberry', 'blueberry', 'elderberry', 'snowberry', 'bunchberry', 'gooseberry',
    'cloudberry', 'strawberry', 'wintergreen_berry', 'cranberry',
    'banana', 'cherry', 'green_apple', 'red_apple', 'lemon', 'olive', 'orange', 'peach', 'plum',
    'melon_slice', 'peanut'
)

# The 24 cakes: the 22 fruit jams plus the two magical ones. Every list below is driven off this, so adding a
# flavour cannot leave a cake, a raw cake or a preview behind.
$allCakes = @($fruits + @('gold_apple', 'enchanted_gold_apple'))

function Clamp([double]$v, [double]$lo, [double]$hi) { if ($v -lt $lo) { return $lo } elseif ($v -gt $hi) { return $hi } else { return $v } }
function Lerp([double]$a, [double]$b, [double]$t) { return $a + ($b - $a) * $t }
function Lum([System.Drawing.Color]$c) { return (0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B) / 255.0 }
# Byte-based luminance for the template loop, which walks about a million pixels: building a Color object per pixel
# there costs far more than the arithmetic does.
function LumB([int]$b, [int]$g, [int]$r) { return (0.299 * $r + 0.587 * $g + 0.114 * $b) / 255.0 }
# Component-wise blend of two three-channel colours, used to veil a ramp with unbaked pastry.
function Mix([object[]]$a, [object[]]$b, [double]$t) {
    return @((Lerp $a[0] $b[0] $t), (Lerp $a[1] $b[1] $t), (Lerp $a[2] $b[2] $t))
}
function ColorOf([double]$r, [double]$g, [double]$b) {
    return [System.Drawing.Color]::FromArgb(255, [int](Clamp $r 0 255), [int](Clamp $g 0 255), [int](Clamp $b 0 255))
}

# Blends a colour toward white just far enough to reach a target brightness. Used to stop the darkest jam colours
# (elderberry, blackberry) from turning their mooncake into an unreadable black blob.
function Lift-To([double[]]$rgb, [double]$target) {
    $w = 0.0
    for ($i = 0; $i -lt 100; $i++) {
        $l = (0.299 * ($rgb[0] + (255 - $rgb[0]) * $w) + 0.587 * ($rgb[1] + (255 - $rgb[1]) * $w) + 0.114 * ($rgb[2] + (255 - $rgb[2]) * $w)) / 255.0
        if ($l -ge $target) { break }
        $w += 0.01
    }
    return @(($rgb[0] + (255 - $rgb[0]) * $w), ($rgb[1] + (255 - $rgb[1]) * $w), ($rgb[2] + (255 - $rgb[2]) * $w))
}

# The icon is 32x32 rather than 16x16: the template's lattice is fine detail that a 16x16 resample turns to mush,
# while 32x32 keeps the pattern readable. Item textures of any size render into the same 16x16 GUI cell, so a
# sharper icon does not look oversized next to the 16x16 TerraFirmaCraft art. A 16x16 set is written to tools/out
# as well, purely so the two can be compared before committing to one.
$iconSize = 32

# Minimum brightness of a cake's base colour, so every cake stays legible regardless of how dark its fruit is.
$BASE_LUM = 0.42

# ================================================================ 1. banana bunch: recoloured cocoa
# Each stage gets its own ramp so the bunch visibly ripens: olive green -> yellow-green -> bright yellow. The
# ramps have three anchors (shadow / body / highlight) and a pixel keeps its brightness ordering, so the pod's
# own shading survives the palette swap.
$bananaRamps = @{
    0 = @(@(71, 89, 28), @(126, 154, 43), @(174, 194, 79))    # unripe: dark olive -> green -> pale green
    1 = @(@(107, 92, 19), @(196, 166, 38), @(228, 206, 94))   # turning: olive gold -> gold -> light gold
    2 = @(@(138, 106, 16), @(224, 190, 36), @(247, 231, 132)) # ripe: amber -> banana yellow -> cream
}

$mc = [System.IO.Compression.ZipFile]::OpenRead($mcJar.FullName)
$work = Join-Path $root 'tools\extract\tex'
New-Item -ItemType Directory -Force -Path $work | Out-Null

foreach ($stage in @(0, 1, 2)) {
    $entry = $mc.Entries | Where-Object { $_.FullName -eq "assets/minecraft/textures/block/cocoa_stage$stage.png" } |
        Select-Object -First 1
    if (-not $entry) { throw "no cocoa_stage$stage.png in the client jar" }
    $tmp = Join-Path $work "cocoa_stage$stage.png"
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $tmp, $true)

    $src = New-Object System.Drawing.Bitmap($tmp)
    $dst = New-Object System.Drawing.Bitmap($src.Width, $src.Height)

    # normalise brightness across the pod, so the ramp spans the art instead of one highlight pixel
    $lo = 1.0; $hi = 0.0
    for ($y = 0; $y -lt $src.Height; $y++) {
        for ($x = 0; $x -lt $src.Width; $x++) {
            $c = $src.GetPixel($x, $y)
            if ($c.A -eq 0) { continue }
            $l = Lum $c
            if ($l -lt $lo) { $lo = $l }
            if ($l -gt $hi) { $hi = $l }
        }
    }
    $span = $hi - $lo
    if ($span -le 0.0001) { $span = 1.0 }

    $ramp = $bananaRamps[$stage]
    for ($y = 0; $y -lt $src.Height; $y++) {
        for ($x = 0; $x -lt $src.Width; $x++) {
            $c = $src.GetPixel($x, $y)
            if ($c.A -eq 0) { continue }
            $t = (Lum $c - $lo) / $span
            if ($t -lt 0.5) {
                $u = $t * 2.0
                $r = Lerp $ramp[0][0] $ramp[1][0] $u
                $g = Lerp $ramp[0][1] $ramp[1][1] $u
                $b = Lerp $ramp[0][2] $ramp[1][2] $u
            } else {
                $u = ($t - 0.5) * 2.0
                $r = Lerp $ramp[1][0] $ramp[2][0] $u
                $g = Lerp $ramp[1][1] $ramp[2][1] $u
                $b = Lerp $ramp[1][2] $ramp[2][2] $u
            }
            $dst.SetPixel($x, $y, (ColorOf $r $g $b))
        }
    }

    $out = Join-Path $texBlock "banana_bunch_stage$stage.png"
    $dst.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output ("banana bunch stage $stage  <- cocoa_stage$stage  (" + $src.Width + "x" + $src.Height + ")")
    $src.Dispose(); $dst.Dispose()
}
$mc.Dispose()

# the model used to point every stage at one image; that stale copy is what made the bunch look like a flattened
# banana. Remove it so nothing silently keeps using the old art.
$oldBunch = Join-Path $texBlock 'banana_bunch.png'
if (Test-Path $oldBunch) { Remove-Item $oldBunch -Force; Write-Output 'removed stale banana_bunch.png' }

# ================================================================ 2. mooncakes: fruit colour from each jam
function Get-Histo([string]$path) {
    $bmp = New-Object System.Drawing.Bitmap($path)
    $h = @{}
    for ($y = 0; $y -lt $bmp.Height; $y++) {
        for ($x = 0; $x -lt $bmp.Width; $x++) {
            $c = $bmp.GetPixel($x, $y)
            if ($c.A -eq 0) { continue }
            $k = ('{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B)
            if ($h.ContainsKey($k)) { $h[$k]++ } else { $h[$k] = 1 }
        }
    }
    $bmp.Dispose()
    return $h
}

$histos = @{}
foreach ($f in $fruits) {
    $p = Join-Path $jamDir "$f.png"
    if (-not (Test-Path $p)) { throw "missing jam texture $p" }
    $histos[$f] = Get-Histo $p
}

# Colours present in every jam are the jar, not the fruit. Intersecting the 22 key sets finds them without
# hardcoding a palette that could silently drift if the jar art is ever regenerated.
# (Plain arrays and -contains rather than a HashSet: PS 5.1 will not new up a generic HashSet from a
#  Dictionary.KeyCollection, and there are only about a dozen distinct colours per jam.)
$shared = @([string[]]$histos[$fruits[0]].Keys)
foreach ($f in $fruits) {
    $keys = [string[]]$histos[$f].Keys
    $shared = @($shared | Where-Object { $keys -contains $_ })
}
Write-Output ("jar colours shared by all jams: " + $shared.Count)

# Every cake is described by a three anchor ramp (shadow / base / highlight):
#   - the 22 jams derive it from their fruit colour
#   - the two gold apple cakes get hand-picked ramps, because a golden apple is not a jam: the plain one is rich
#     gold, and the enchanted one is gold with violet shadow and sheen, which is the only cue a player gets that
#     it is the rare one
$ramps = @{}
foreach ($f in $fruits) {
    $best = $null; $bestCount = 0
    foreach ($k in $histos[$f].Keys) {
        if ($shared -contains $k) { continue }
        if ($histos[$f][$k] -gt $bestCount) { $bestCount = $histos[$f][$k]; $best = $k }
    }
    if (-not $best) { throw "could not find a fruit colour in jam $f" }

    $r = [Convert]::ToInt32($best.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($best.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($best.Substring(4, 2), 16)

    # Some jams are extremely dark (elderberry #520053, blackberry #3F2665). Used raw they would make a cake that
    # reads as a black blob in the inventory, so the base anchor is lifted to a minimum brightness by blending
    # toward white - which keeps the hue and just makes it legible. Bright fruits are left untouched.
    $base = Lift-To @([double]$r, [double]$g, [double]$b) $BASE_LUM

    # The three anchors are computed into named variables rather than inline. An array literal with a trailing
    # comma followed by a '#' comment on the same line confuses the PowerShell 5.1 tokenizer badly enough to throw
    # "op_Multiply" on an Object[], which is a nasty way to lose half an hour.
    $shR = $base[0] * 0.30; $shG = $base[1] * 0.30; $shB = $base[2] * 0.30
    $hiR = $base[0] + (255 - $base[0]) * 0.58; $hiG = $base[1] + (255 - $base[1]) * 0.58; $hiB = $base[2] + (255 - $base[2]) * 0.58
    $ramps[$f] = @(@($shR, $shG, $shB), @($base[0], $base[1], $base[2]), @($hiR, $hiG, $hiB))
    Write-Output ("  " + $f.PadRight(20) + " #" + $best + "  ->  #" + ('{0:X2}{1:X2}{2:X2}' -f [int]$base[0], [int]$base[1], [int]$base[2]))
}
$ramps['gold_apple'] = @(@(96, 62, 8), @(232, 168, 34), @(255, 233, 150))
$ramps['enchanted_gold_apple'] = @(@(58, 26, 96), @(216, 152, 40), @(246, 216, 255))
Write-Output '  gold_apple            #E8A822'
Write-Output '  enchanted_gold_apple  #D89828 with violet shadow and sheen'

# The unbaked cakes. Same filling hue, veiled with pale pastry, so a raw cake still tells the player which jar it
# came from without looking like a finished one. The veil is heavier on the highlight than on the shadow, which is
# what makes it read as dry dough rather than as a washed out cake.
$RAW_PASTRY = @(233.0, 216.0, 181.0)
$rawRamps = @{}
foreach ($cake in $allCakes) {
    $r = $ramps[$cake]
    $rawRamps[$cake] = @(
        (Mix $r[0] $RAW_PASTRY 0.60),
        (Mix $r[1] $RAW_PASTRY 0.70),
        (Mix $r[2] $RAW_PASTRY 0.78)
    )
}

# ================================================================ 3. the template, read once
# The template is a smooth ~1254px render, not blocky pixel art: its fine lattice and soft shading are exactly what
# makes it look good, and they are also exactly what a 32x32 resample destroys. So the crop is resampled separately
# for each size that is actually written (see $SHIP_SIZE), rather than resampled once at a small size and then
# stretched up, which is what made the first attempt look rough.
$template = Join-Path $root 'mooncake.png'
if (-not (Test-Path $template)) { throw "no mooncake template at $template" }

$tpl = New-Object System.Drawing.Bitmap($template)
$tw = $tpl.Width; $th = $tpl.Height
$trect = New-Object System.Drawing.Rectangle(0, 0, $tw, $th)
$lock = $tpl.LockBits($trect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$tstride = $lock.Stride
$tbuf = New-Object byte[] ($tstride * $th)
[System.Runtime.InteropServices.Marshal]::Copy($lock.Scan0, $tbuf, 0, $tbuf.Length)
$tpl.UnlockBits($lock)
$tpl.Dispose()

# Crop to a square around the opaque art, plus a little breathing room, so the cake is centred and as large as it
# can be inside the icon.
$minx = $tw; $maxx = -1; $miny = $th; $maxy = -1
for ($y = 0; $y -lt $th; $y++) {
    for ($x = 0; $x -lt $tw; $x++) {
        if ($tbuf[$y * $tstride + $x * 4 + 3] -gt 8) {
            if ($x -lt $minx) { $minx = $x }
            if ($x -gt $maxx) { $maxx = $x }
            if ($y -lt $miny) { $miny = $y }
            if ($y -gt $maxy) { $maxy = $y }
        }
    }
}
$cropSide = [int]([Math]::Max($maxx - $minx + 1, $maxy - $miny + 1) * 1.06)
$cropX = [int]([Math]::Round(($minx + $maxx) / 2.0 - $cropSide / 2.0))
$cropY = [int]([Math]::Round(($miny + $maxy) / 2.0 - $cropSide / 2.0))
Write-Output ("template " + $tw + "x" + $th + "  art " + ($maxx - $minx + 1) + "x" + ($maxy - $miny + 1) + "  crop " + $cropSide + " at (" + $cropX + "," + $cropY + ")")

# Resamples the crop into a size x size grid of brightness and coverage.
#
# Sources are visited in order rather than testing each cell's whole footprint, so the cost is proportional to the
# template's pixels for any output size. Colour is accumulated premultiplied by alpha and divided out afterwards,
# which is what stops the transparent background bleeding dark pixels into the cake's edge.
function Build-Grid([int]$size) {
    $cells = $size * $size
    $alphaSum = New-Object double[] $cells
    $weightSum = New-Object double[] $cells
    $lumSum = New-Object double[] $cells
    for ($sy = $cropY; $sy -lt ($cropY + $cropSide); $sy++) {
        if ($sy -lt 0 -or $sy -ge $th) { continue }
        $dy = [int]([Math]::Floor(($sy - $cropY) * $size / $cropSide))
        if ($dy -lt 0 -or $dy -ge $size) { continue }
        $rowBase = $dy * $size
        $o = $sy * $tstride + $cropX * 4
        for ($sx = $cropX; $sx -lt ($cropX + $cropSide); $sx++) {
            if ($sx -ge 0 -and $sx -lt $tw) {
                $dx = [int]([Math]::Floor(($sx - $cropX) * $size / $cropSide))
                if ($dx -ge 0 -and $dx -lt $size) {
                    $idx = $rowBase + $dx
                    $weightSum[$idx] += 1.0
                    $a = $tbuf[$o + 3] / 255.0
                    $alphaSum[$idx] += $a
                    if ($a -gt 0) { $lumSum[$idx] += $a * (LumB $tbuf[$o] $tbuf[$o + 1] $tbuf[$o + 2]) }
                }
            }
            $o += 4
        }
    }

    $lum = New-Object double[] $cells
    $cov = New-Object double[] $cells
    for ($i = 0; $i -lt $cells; $i++) {
        $cov[$i] = if ($weightSum[$i] -gt 0) { $alphaSum[$i] / $weightSum[$i] } else { 0.0 }
        $lum[$i] = if ($alphaSum[$i] -gt 0) { $lumSum[$i] / $alphaSum[$i] } else { 0.0 }
    }

    # Stretch the brightness range so the ramp spans the cake rather than wasting itself on outliers. The 5th and
    # 95th percentiles are used rather than min/max, which one stray pixel could distort.
    $seen = New-Object System.Collections.Generic.List[double]
    for ($i = 0; $i -lt $cells; $i++) { if ($cov[$i] -gt 0.6) { $seen.Add($lum[$i]) } }
    $sortedLum = $seen | Sort-Object
    $n = $sortedLum.Count
    $lo = $sortedLum[[int]($n * 0.05)]
    $hi = $sortedLum[[int]($n * 0.95)]
    if ($hi - $lo -le 0.0001) { $hi = $lo + 1.0 }
    for ($i = 0; $i -lt $cells; $i++) { $lum[$i] = (Clamp (($lum[$i] - $lo) / ($hi - $lo)) 0.0 1.0) }

    return @{ Lum = $lum; Cov = $cov; Lo = $lo; Hi = $hi; Size = $size }
}

# ================================================================ 4. cake and jam rendering
# The base anchor sits at 0.46 on the brightness axis so the cake's average brightness comes out as the fruit colour
# itself, which is what makes each icon read as "the blueberry one".
$T_BASE = 0.46
function Ramp-Color([object[]]$ramp, [double]$t) {
    if ($t -le $T_BASE) {
        $u = $t / $T_BASE
        return @((Lerp $ramp[0][0] $ramp[1][0] $u), (Lerp $ramp[0][1] $ramp[1][1] $u), (Lerp $ramp[0][2] $ramp[1][2] $u))
    }
    $u = ($t - $T_BASE) / (1.0 - $T_BASE)
    return @((Lerp $ramp[1][0] $ramp[2][0] $u), (Lerp $ramp[1][1] $ramp[2][1] $u), (Lerp $ramp[1][2] $ramp[2][2] $u))
}

# Renders one cake from a prebuilt brightness grid and colour ramp and returns the file size.
#
# Pixels are written through LockBits, not SetPixel: SetPixel goes through a reflection call and marshals a Color
# object per pixel, which for tens of thousands of pixels per cake turns a two second job into minutes. This builds
# a plain BGRA byte buffer and copies it in one go.
function Render-Cake([hashtable]$grid, [object[]]$ramp, [string]$file) {
    $size = $grid.Size
    $lum = $grid.Lum
    $cov = $grid.Cov

    # precompute the ramp into a 256-entry lookup, so the per-pixel work is an array read and not three lerps
    $rTab = New-Object byte[] 256
    $gTab = New-Object byte[] 256
    $bTab = New-Object byte[] 256
    for ($t = 0; $t -lt 256; $t++) {
        $c = Ramp-Color $ramp ($t / 255.0)
        $rTab[$t] = [byte](Clamp $c[0] 0 255)
        $gTab[$t] = [byte](Clamp $c[1] 0 255)
        $bTab[$t] = [byte](Clamp $c[2] 0 255)
    }

    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $lock = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $lock.Stride
    $buf = New-Object byte[] ($stride * $size)
    for ($y = 0; $y -lt $size; $y++) {
        $rowBase = $y * $size
        $o = $y * $stride
        for ($x = 0; $x -lt $size; $x++) {
            $idx = $rowBase + $x
            $a = $cov[$idx]
            if ($a -le 0) { $o += 4; continue }
            $t = [int]($lum[$idx] * 255)
            if ($t -lt 0) { $t = 0 } elseif ($t -gt 255) { $t = 255 }
            $buf[$o] = $bTab[$t]
            $buf[$o + 1] = $gTab[$t]
            $buf[$o + 2] = $rTab[$t]
            $buf[$o + 3] = [byte](Clamp ($a * 255 + 0.5) 0 255)
            $o += 4
        }
    }
    [System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $lock.Scan0, $buf.Length)
    $bmp.UnlockBits($lock)
    $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return (Get-Item $file).Length
}

# ================================================================ 4b. the two golden apple jams
# There is no TFC art for these, so they are made from an existing jar: the jar itself is identical in all 22 jam
# files (that is how the shared colour set is found in the first place), so repainting only the non-jar pixels turns
# any of them into a new flavour. Using strawberry's layout keeps the fruit blob where the other jams have theirs.
function Save-Jam([string]$name, [object[]]$ramp) {
    $src = New-Object System.Drawing.Bitmap((Join-Path $jamDir 'strawberry.png'))
    $w = $src.Width; $h = $src.Height

    # brightness range over the fruit pixels only, so the ramp spans the fruit and not the jar
    $lo = 1.0; $hi = 0.0; $sum = 0.0; $count = 0
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $c = $src.GetPixel($x, $y)
            if ($c.A -eq 0) { continue }
            $k = ('{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B)
            if ($shared -contains $k) { continue }
            $l = Lum $c
            if ($l -lt $lo) { $lo = $l }
            if ($l -gt $hi) { $hi = $l }
            $sum += $l; $count++
        }
    }
    $span = $hi - $lo
    if ($span -le 0.0001) { $span = 1.0 }

    # A jam's fruit sits in a NARROW brightness band (its four or five pulp shades are all much the same tone), so
    # stretching that band across the whole ramp would push the average pulp to the highlight and the jar would come
    # out nearly white. Scaling the normalised value so the MEAN fruit pixel lands on the ramp's base anchor instead
    # keeps the pulp at the fruit's own colour, which is the whole point of painting a new flavour.
    $meanT = ($sum / $count - $lo) / $span
    $scale = if ($meanT -gt 0.01) { $T_BASE / $meanT } else { 1.0 }

    $dst = New-Object System.Drawing.Bitmap($w, $h)
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $c = $src.GetPixel($x, $y)
            if ($c.A -eq 0) { continue }
            $k = ('{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B)
            if ($shared -contains $k) {
                $dst.SetPixel($x, $y, $c)   # the jar: untouched, so it still matches the other 22
                continue
            }
            $t = (Clamp (((Lum $c - $lo) / $span) * $scale) 0.0 1.0)
            $col = Ramp-Color $ramp $t
            $dst.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(
                255, [int](Clamp $col[0] 0 255), [int](Clamp $col[1] 0 255), [int](Clamp $col[2] 0 255)))
        }
    }
    $dst.Save((Join-Path $jamDir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $dst.Dispose()
    $src.Dispose()
}

New-Item -ItemType Directory -Force -Path $jamDir | Out-Null
Save-Jam 'gold_apple' $ramps['gold_apple']
Save-Jam 'enchanted_gold_apple' $ramps['enchanted_gold_apple']
Write-Output 'golden apple jam textures written: food/jam/gold_apple.png, food/jam/enchanted_gold_apple.png'

# ================================================================ 4c. banana leaves: vanilla jungle leaves, pre-tinted
# The banana's leaves are meant to BE vanilla jungle leaves, so the block model used to parent minecraft:block/jungle_leaves
# and borrow its texture. That rendered them WHITE, and here is why: minecraft:block/leaves puts "tintindex": 0 on all
# six faces, and vanilla's jungle_leaves.png is a GREYSCALE mask (its pixels are #888787, #B7B9B7, ...) that only
# becomes green at render time because vanilla registers a foliage colour provider for minecraft:jungle_leaves. A
# custom leaf block has no such provider, so the tint resolves to white and the grey mask shows through as grey-white.
#
# The fix is to bake the tint in: take vanilla's actual leaf texture and multiply it by the foliage colour that
# vanilla would have applied, so the tint is part of our image and our block needs no colour provider at all.
#
# The colour comes from vanilla's own foliage colour map, not from a guess. FoliageColor.get(temp, rain) indexes
# "assets/minecraft/textures/colormap/foliage.png" as (y << 8 | x) with
#     rain *= temp;  x = (1 - temp) * 255;  y = (1 - rain) * 255
# and jungle is temperature 0.95 / downfall 0.8. Note the [Math]::Floor: Java's (int) cast TRUNCATES, whereas
# PowerShell's [int] ROUNDS, which would land one column to the right of the pixel vanilla actually reads.
# FoliageColor.FOLIAGE_DEFAULT (0xFF48B518, rgb 72,181,24) is printed alongside for comparison, since that is the
# constant vanilla falls back to when no biome applies - which, once the tint is baked, is exactly our situation.
$foliagePng = Join-Path $work 'foliage.png'
$jungleLeavesPng = Join-Path $work 'jungle_leaves.png'
$mc2 = [System.IO.Compression.ZipFile]::OpenRead($mcJar.FullName)
foreach ($spec in @(@('assets/minecraft/textures/colormap/foliage.png', $foliagePng),
                    @('assets/minecraft/textures/block/jungle_leaves.png', $jungleLeavesPng))) {
    $entry = $mc2.Entries | Where-Object { $_.FullName -eq $spec[0] } | Select-Object -First 1
    if (-not $entry) { throw ("client jar is missing " + $spec[0]) }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $spec[1], $true)
}
$mc2.Dispose()

$colormap = New-Object System.Drawing.Bitmap($foliagePng)
$jungleTemp = 0.95; $jungleRain = 0.8
$rain = $jungleRain * $jungleTemp
$ix = [int][Math]::Floor((1.0 - $jungleTemp) * 255.0)
$iy = [int][Math]::Floor((1.0 - $rain) * 255.0)
$tint = $colormap.GetPixel($ix, $iy)
$colormap.Dispose()
Write-Output ("jungle foliage tint from the vanilla colormap at (x=" + $ix + ",y=" + $iy + "): #" + ('{0:X2}{1:X2}{2:X2}' -f $tint.R, $tint.G, $tint.B) + "   (FoliageColor.FOLIAGE_DEFAULT is #48B518)")

$leafSrc = New-Object System.Drawing.Bitmap($jungleLeavesPng)
$leafOut = New-Object System.Drawing.Bitmap($leafSrc.Width, $leafSrc.Height)
for ($y = 0; $y -lt $leafSrc.Height; $y++) {
    for ($x = 0; $x -lt $leafSrc.Width; $x++) {
        $c = $leafSrc.GetPixel($x, $y)
        if ($c.A -eq 0) { continue }
        # multiply, which is what the renderer would have done with the tint
        $r = $c.R * $tint.R / 255.0
        $g = $c.G * $tint.G / 255.0
        $b = $c.B * $tint.B / 255.0
        $leafOut.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(
            $c.A, [int](Clamp $r 0 255), [int](Clamp $g 0 255), [int](Clamp $b 0 255)))
    }
}
$bananaLeafPath = Join-Path $texBlock 'banana_leaves.png'
$leafOut.Save($bananaLeafPath, [System.Drawing.Imaging.ImageFormat]::Png)
$leafOut.Dispose(); $leafSrc.Dispose()
Write-Output ("banana leaves texture written: block/plant/banana_leaves.png  (vanilla jungle_leaves baked with the jungle tint)")

# ================================================================ 5. write the icons
# Each cake is written as its own PNG. There is no sprite sheet anywhere in the mod: every cake and every raw cake is
# an independent file, and the enlarged previews written further down are also one file per icon, so nothing has to
# be cut apart to be looked at.
#
# 128x128 is the shipped size. The GUI draws an item icon into a 16x16 cell, so the file's pixel count is not what
# the player sees; what matters is that a high quality minification keeps the stamped lattice legible, and 128 is
# comfortably past the point where it does. The grid is resampled STRAIGHT FROM the 1254px template rather than from
# an intermediate, which is what keeps the lattice sharp - going through a small intermediate first is exactly what
# made the first attempt look rough.
$SHIP_SIZE = 128
$mooncakeDir = Join-Path $texItem 'food\mooncake'
$rawMooncakeDir = Join-Path $texItem 'food\raw_mooncake'
foreach ($d in @($mooncakeDir, $rawMooncakeDir)) { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
New-Item -ItemType Directory -Force -Path $mooncakeDir, $rawMooncakeDir | Out-Null

$grid = Build-Grid $SHIP_SIZE
Write-Output ("template " + $tw + "x" + $th + " -> grid " + $SHIP_SIZE + "x" + $SHIP_SIZE + ", brightness p5 " + [Math]::Round($grid.Lo, 3) + " p95 " + [Math]::Round($grid.Hi, 3))

$bakedBytes = 0
$rawBytes = 0
foreach ($cake in $allCakes) { $bakedBytes += Render-Cake $grid $ramps[$cake] (Join-Path $mooncakeDir "$cake.png") }
foreach ($cake in $allCakes) { $rawBytes += Render-Cake $grid $rawRamps[$cake] (Join-Path $rawMooncakeDir "$cake.png") }
Write-Output ("baked mooncakes: " + $allCakes.Count + " files, " + [Math]::Round($bakedBytes / 1024.0, 1) + " KB  -> textures/item/food/mooncake/")
Write-Output ("raw mooncakes  : " + $allCakes.Count + " files, " + [Math]::Round($rawBytes / 1024.0, 1) + " KB  -> textures/item/food/raw_mooncake/")

# ================================================================ 6. per cake previews, for eyeballing
# One enlarged file per cake, at both the shipped size and the size the player actually sees: the 16px strip is the
# one that answers "is the lattice still readable in the inventory", and it is included because a preview at 4x can
# look lovely while the icon in game is mush. Each preview stacks the baked cake over the raw one.
$previewDir = Join-Path $outDir 'mooncake-preview'
if (Test-Path $previewDir) { Remove-Item $previewDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $previewDir | Out-Null

$previewScale = 4
$guiCell = 16
foreach ($cake in $allCakes) {
    $pad = 12
    $big = $SHIP_SIZE * $previewScale
    $strip = $guiCell * 6
    # two rows of (texture at 4x over its 16px GUI rendering): the baked cake on top, the raw one below
    $ow = [int]($big + 2 * $pad)
    $oh = [int](2 * ($big + $pad + $strip) + 2 * $pad)
    $out = New-Object System.Drawing.Bitmap -ArgumentList $ow, $oh
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 40, 40, 48))

    $row = 0
    foreach ($srcPath in @((Join-Path $mooncakeDir "$cake.png"), (Join-Path $rawMooncakeDir "$cake.png"))) {
        $src = New-Object System.Drawing.Bitmap($srcPath)
        $top = [int]($pad + $row * ($big + $pad + $strip))

        # the shipped texture at 4x, nearest neighbour so the pixels are honest rather than smoothed
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $g.DrawImage($src, [int]$pad, $top, [int]$big, [int]$big)

        # the same texture minified to a 16x16 GUI cell with a high quality filter, then blown back up 6x
        $small = New-Object System.Drawing.Bitmap -ArgumentList ([int]$guiCell), ([int]$guiCell)
        $sg = [System.Drawing.Graphics]::FromImage($small)
        $sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $sg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $sg.DrawImage($src, 0, 0, [int]$guiCell, [int]$guiCell)
        $sg.Dispose()
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $g.DrawImage($small, [int]$pad, [int]($top + $big), [int]$strip, [int]$strip)
        $small.Dispose()
        $src.Dispose()
        $row++
    }

    $g.Dispose()
    $out.Save((Join-Path $previewDir "$cake.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
}
Write-Output ("per cake previews: tools/out/mooncake-preview/<name>.png  (" + $allCakes.Count + " files, one per cake)")
Write-Output '  each shows the baked cake 4x + its 16px GUI rendering, then the raw cake the same way'
Write-Output '  the two golden apple jams are also written: textures/item/food/jam/gold_apple.png and _enchanted_'
