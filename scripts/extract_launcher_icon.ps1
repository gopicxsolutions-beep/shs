# Derives app-launcher-icon source images from the real NavaSakhi brand
# lockup (assets/images/navasakhi_logo.png), which is a full logo — circular
# emblem + "NavaSakhi" wordmark + tagline — too text-heavy to use as-is for
# a launcher icon (unreadable at 48x48, and app icons shouldn't carry a
# tagline). This crops just the circular emblem, which is what
# flutter_launcher_icons (see pubspec.yaml's flutter_launcher_icons: block)
# reads from assets/icon/.
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$src = "$root/assets/images/navasakhi_logo.png"
$outDir = "$root/assets/icon"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

$logo = [System.Drawing.Bitmap]::FromFile($src)

# Bounding box of the circular emblem itself (decorative ring + figures),
# found by scanning for non-white pixels while excluding rows below y=513
# where the "NavaSakhi" wordmark begins (row 514 is the one fully-blank
# row separating them — emblem bbox is x:[164,628] y:[44,512]).
$cropX = 156; $cropY = 34; $cropSize = 480

$emblem = New-Object System.Drawing.Bitmap $cropSize, $cropSize, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($emblem)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$srcRect = New-Object System.Drawing.Rectangle $cropX, $cropY, $cropSize, $cropSize
$destRect = New-Object System.Drawing.Rectangle 0, 0, $cropSize, $cropSize
$g.DrawImage($logo, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$emblem.Save("$outDir/icon.png", [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Wrote $outDir/icon.png ($cropSize x $cropSize, cropped emblem)"

# This same full-bleed crop is also used as adaptive_icon_foreground in
# pubspec.yaml -- flutter_launcher_icons already wraps the Android adaptive
# foreground drawable in a 16% <inset> (see the generated
# android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml), which is
# itself the safe-zone margin. Adding a second round of padding here would
# double up and shrink the glyph too far inside the mask.

$emblem.Dispose(); $logo.Dispose()
Write-Host "Done. Run: dart run flutter_launcher_icons"
