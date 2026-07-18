# Generates real branded app icons (replacing the default Flutter template
# logo) for Android, iOS, and Web. Simple mark: a bold white "S" on the
# app's brand-green background (Brand.c600 = #0E8A66 in lib/theme/colors.dart),
# matching the rounded-square + brand-color glyph style already used for the
# onboarding icons in login_page.dart/otp_page.dart/profile_setup_page.dart.
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$brandGreen = [System.Drawing.Color]::FromArgb(255, 14, 138, 102)
$white = [System.Drawing.Color]::White

function New-IconBitmap {
    param(
        [int]$Size,
        [double]$GlyphScale = 0.62,
        [bool]$Opaque = $false
    )
    $format = if ($Opaque) { [System.Drawing.Imaging.PixelFormat]::Format24bppRgb } else { [System.Drawing.Imaging.PixelFormat]::Format32bppArgb }
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size, $format
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear($brandGreen)

    $fontSize = [double]$Size * $GlyphScale
    $font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $format2 = New-Object System.Drawing.StringFormat
    $format2.Alignment = [System.Drawing.StringAlignment]::Center
    $format2.LineAlignment = [System.Drawing.StringAlignment]::Center
    $brush = New-Object System.Drawing.SolidBrush($white)
    $rect = New-Object System.Drawing.RectangleF(0, 0, $Size, $Size)
    # Nudge up slightly — "S" glyphs in most fonts sit a touch low visually.
    $rect.Y = $Size * -0.03
    $g.DrawString("S", $font, $brush, $rect, $format2)

    $brush.Dispose(); $font.Dispose(); $g.Dispose()
    return $bmp
}

function Save-Resized {
    param($Master, [int]$Size, [string]$Path, [bool]$Opaque = $false)
    $format = if ($Opaque) { [System.Drawing.Imaging.PixelFormat]::Format24bppRgb } else { [System.Drawing.Imaging.PixelFormat]::Format32bppArgb }
    $out = New-Object System.Drawing.Bitmap $Size, $Size, $format
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($Master, 0, 0, $Size, $Size)
    $g.Dispose()
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $out.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
    Write-Host "Wrote $Path ($Size x $Size)"
}

# Master icons rendered at high resolution, then downscaled per target —
# crisper than upscaling a small bitmap.
$masterOpaque = New-IconBitmap -Size 1024 -GlyphScale 0.62 -Opaque $true
$masterAlpha = New-IconBitmap -Size 1024 -GlyphScale 0.62 -Opaque $false
$masterMaskable = New-IconBitmap -Size 1024 -GlyphScale 0.42 -Opaque $false   # smaller glyph — safe zone for maskable icons

# --- Android mipmaps ---
$androidSizes = @{ "mipmap-mdpi" = 48; "mipmap-hdpi" = 72; "mipmap-xhdpi" = 96; "mipmap-xxhdpi" = 144; "mipmap-xxxhdpi" = 192 }
foreach ($dir in $androidSizes.Keys) {
    Save-Resized -Master $masterAlpha -Size $androidSizes[$dir] -Path "$root/android/app/src/main/res/$dir/ic_launcher.png"
}

# --- iOS AppIcon.appiconset (opaque — Apple rejects icons with alpha) ---
$iosSet = "$root/ios/Runner/Assets.xcassets/AppIcon.appiconset"
$iosSizes = @{
    "Icon-App-20x20@1x.png" = 20; "Icon-App-20x20@2x.png" = 40; "Icon-App-20x20@3x.png" = 60
    "Icon-App-29x29@1x.png" = 29; "Icon-App-29x29@2x.png" = 58; "Icon-App-29x29@3x.png" = 87
    "Icon-App-40x40@1x.png" = 40; "Icon-App-40x40@2x.png" = 80; "Icon-App-40x40@3x.png" = 120
    "Icon-App-60x60@2x.png" = 120; "Icon-App-60x60@3x.png" = 180
    "Icon-App-76x76@1x.png" = 76; "Icon-App-76x76@2x.png" = 152
    "Icon-App-83.5x83.5@2x.png" = 167
    "Icon-App-1024x1024@1x.png" = 1024
}
foreach ($name in $iosSizes.Keys) {
    Save-Resized -Master $masterOpaque -Size $iosSizes[$name] -Path "$iosSet/$name" -Opaque $true
}

# --- Web ---
Save-Resized -Master $masterAlpha -Size 192 -Path "$root/web/icons/Icon-192.png"
Save-Resized -Master $masterAlpha -Size 512 -Path "$root/web/icons/Icon-512.png"
Save-Resized -Master $masterMaskable -Size 192 -Path "$root/web/icons/Icon-maskable-192.png"
Save-Resized -Master $masterMaskable -Size 512 -Path "$root/web/icons/Icon-maskable-512.png"
Save-Resized -Master $masterAlpha -Size 16 -Path "$root/web/favicon.png"

$masterOpaque.Dispose(); $masterAlpha.Dispose(); $masterMaskable.Dispose()
Write-Host "Done."
