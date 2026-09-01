Add-Type -AssemblyName System.Drawing
$out = "D:\MYApp\prashn_reel_v2_firebase\prashn_reel_v2\play-listing"
$src = Join-Path $out "icon-512.png"

$inkDeep = [System.Drawing.Color]::FromArgb(0x17,0x11,0x0b)
$inkLift = [System.Drawing.Color]::FromArgb(0x3a,0x2b,0x1c)
$goldHi  = [System.Drawing.Color]::FromArgb(0xf2,0xcf,0x6e)
$cream   = [System.Drawing.Color]::FromArgb(0xE8,0xDA,0xC2)

# ---------- 1. Developer icon: 512x512, 24-bit, bina transparency ----------
$icon = [System.Drawing.Image]::FromFile($src)
$bmp  = New-Object System.Drawing.Bitmap 512,512,([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g    = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear($inkDeep)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($icon, (New-Object System.Drawing.Rectangle 0,0,512,512))
$g.Dispose()
$devIcon = Join-Path $out "developer-icon-512.png"
$bmp.Save($devIcon, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
"icon banaya : $devIcon"

# ---------- 2. Header image: 4096x2304 ----------
$W = 4096; $H = 2304
$hdr = New-Object System.Drawing.Bitmap $W,$H,([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g2  = [System.Drawing.Graphics]::FromImage($hdr)
$g2.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g2.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

$rect = New-Object System.Drawing.Rectangle 0,0,$W,$H
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $inkLift, $inkDeep, 35.0)
$g2.FillRectangle($brush, $rect)
$brush.Dispose()

# icon — beech me, thoda upar
$iconSize = 460
$ix = [int](($W - $iconSize)/2)
$iy = [int]($H*0.5 - $iconSize - 90)
$g2.DrawImage($icon, (New-Object System.Drawing.Rectangle $ix,$iy,$iconSize,$iconSize))

$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = [System.Drawing.StringAlignment]::Center

$fTitle = New-Object System.Drawing.Font("Nirmala UI", 210, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$bTitle = New-Object System.Drawing.SolidBrush $goldHi
$g2.DrawString("ब्रह्मास्त्र", $fTitle, $bTitle, [single]($W/2), [single]($H*0.5 - 40), $fmt)

$fSub = New-Object System.Drawing.Font("Nirmala UI", 84, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$bSub = New-Object System.Drawing.SolidBrush $cream
$g2.DrawString("यूपी पीईटी  ·  आरओ/एआरओ  ·  यूपीपीसीएस", $fSub, $bSub, [single]($W/2), [single]($H*0.5 + 265), $fmt)

$g2.Dispose()
$hdrPath = Join-Path $out "developer-header-4096x2304.png"
$hdr.Save($hdrPath, [System.Drawing.Imaging.ImageFormat]::Png)
$hdr.Dispose()
$icon.Dispose()
"header banaya : $hdrPath"
