param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$sourcePath = Join-Path $ProjectRoot 'design/app-icon/source.png'
$resources = Join-Path $ProjectRoot 'android/app/src/main/res'
$source = [Drawing.Image]::FromFile($sourcePath)
try {
    if ($source.Width -ne $source.Height) { throw 'Launcher source must be square.' }
    $targets = @(
        @{ Directory = 'mipmap-mdpi'; Size = 48 },
        @{ Directory = 'mipmap-hdpi'; Size = 72 },
        @{ Directory = 'mipmap-xhdpi'; Size = 96 },
        @{ Directory = 'mipmap-xxhdpi'; Size = 144 },
        @{ Directory = 'mipmap-xxxhdpi'; Size = 192 },
        @{ Directory = 'drawable-nodpi'; Size = 432 }
    )
    foreach ($target in $targets) {
        $size = $target.Size
        $bitmap = [Drawing.Bitmap]::new($size, $size)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.Clear([Drawing.ColorTranslator]::FromHtml('#EAF4FF'))
            # Adaptive layers are 108dp. Place the supplied square at 84dp so
            # its central wallet remains inside Android's 66dp safe zone.
            $inset = if ($target.Directory -eq 'drawable-nodpi') { 48 } else { 0 }
            $edge = $size - 2 * $inset
            $graphics.DrawImage($source, [Drawing.Rectangle]::new($inset, $inset, $edge, $edge))
            $directory = Join-Path $resources $target.Directory
            New-Item -ItemType Directory -Force -Path $directory | Out-Null
            $name = if ($target.Directory -eq 'drawable-nodpi') { 'pocketflow_launcher_art.png' } else { 'ic_launcher.png' }
            $bitmap.Save((Join-Path $directory $name), [Drawing.Imaging.ImageFormat]::Png)
            Write-Output "$($target.Directory)/$name : ${size}x${size}"
        } finally { $graphics.Dispose(); $bitmap.Dispose() }
    }
} finally { $source.Dispose() }
