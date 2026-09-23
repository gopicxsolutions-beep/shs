# Renders the generated adaptive-icon (white background + icon_foreground.png)
# under Android's real launcher mask shapes (circle, squircle, rounded square)
# plus the plain legacy square, so the icon can be sanity-checked without a
# device/emulator. Output: a temp PNG shown via the Read tool.
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$bg = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$fgPath = "$root/assets/icon/icon.png"
$legacyPath = "$root/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"

$tile = 220
$gap = 24
$cols = 4
$canvasW = $cols * $tile + ($cols + 1) * $gap
$canvasH = $tile + 2 * $gap + 40

$canvas = New-Object System.Drawing.Bitmap $canvasW, $canvasH
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::FromArgb(255, 235, 235, 235))

$fg = [System.Drawing.Bitmap]::FromFile($fgPath)
$legacy = [System.Drawing.Bitmap]::FromFile($legacyPath)

function Draw-MaskedTile {
    param($Graphics, [int]$X, [int]$Y, [int]$Size, [string]$ShapeType, $SourceImage, [bool]$Legacy = $false)
    $tileBmp = New-Object System.Drawing.Bitmap $Size, $Size
    $tg = [System.Drawing.Graphics]::FromImage($tileBmp)
    $tg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $tg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    switch ($ShapeType) {
        "circle" { $path.AddEllipse(0, 0, $Size, $Size) }
        "squircle" {
            # Approximate a squircle with a heavily rounded rect (Android's
            # actual squircle mask uses a superellipse; a large corner radius
            # reads close enough for a visual sanity check).
            $r = [int]($Size * 0.32)
            $path.AddArc(0, 0, $r*2, $r*2, 180, 90)
            $path.AddArc($Size-$r*2, 0, $r*2, $r*2, 270, 90)
            $path.AddArc($Size-$r*2, $Size-$r*2, $r*2, $r*2, 0, 90)
            $path.AddArc(0, $Size-$r*2, $r*2, $r*2, 90, 90)
            $path.CloseFigure()
        }
        "rounded" {
            $r = [int]($Size * 0.16)
            $path.AddArc(0, 0, $r*2, $r*2, 180, 90)
            $path.AddArc($Size-$r*2, 0, $r*2, $r*2, 270, 90)
            $path.AddArc($Size-$r*2, $Size-$r*2, $r*2, $r*2, 0, 90)
            $path.AddArc(0, $Size-$r*2, $r*2, $r*2, 90, 90)
            $path.CloseFigure()
        }
        "square" { $path.AddRectangle((New-Object System.Drawing.Rectangle 0,0,$Size,$Size)) }
    }
    $tg.SetClip($path)
    if ($Legacy) {
        $tg.DrawImage($SourceImage, 0, 0, $Size, $Size)
    } else {
        $tg.Clear([System.Drawing.Color]::White)
        # Match the ACTUAL generated mipmap-anydpi-v26/ic_launcher.xml, which
        # wraps the foreground drawable in <inset android:inset="16%"/> --
        # i.e. Android shrinks our already-padded icon_foreground.png by a
        # further 16% per side before masking. Reproduce that here instead of
        # guessing, since double-padding (our own safe zone + this inset)
        # could otherwise make the glyph look too small on a real device.
        $insetSize = [int]($Size * (1 - 2 * 0.16))
        $offset = [int](($Size - $insetSize) / 2)
        $tg.DrawImage($SourceImage, $offset, $offset, $insetSize, $insetSize)
    }
    $tg.ResetClip()
    $tg.DrawPath((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255,210,210,210)), 1), $path)
    $tg.Dispose()

    $Graphics.DrawImage($tileBmp, $X, $Y)
    $tileBmp.Dispose()
    $path.Dispose()
}

$labels = @("Circle (Pixel)", "Squircle (Samsung)", "Rounded square", "Legacy square")
$shapes = @("circle", "squircle", "rounded", "square")
for ($i = 0; $i -lt 4; $i++) {
    $x = $gap + $i * ($tile + $gap)
    $y = $gap
    $isLegacy = ($shapes[$i] -eq "square")
    Draw-MaskedTile -Graphics $g -X $x -Y $y -Size $tile -ShapeType $shapes[$i] -SourceImage $(if ($isLegacy) { $legacy } else { $fg }) -Legacy $isLegacy

    $labelFont = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Regular)
    $labelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,60,60,60))
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($labels[$i], $labelFont, $labelBrush, (New-Object System.Drawing.RectangleF $x, ($y+$tile+6), $tile, 30), $fmt)
}

$outPath = "$env:TEMP\navasakhi_icon_mask_preview.png"
$canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $canvas.Dispose(); $fg.Dispose(); $legacy.Dispose()
Write-Host "Wrote $outPath"
