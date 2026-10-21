param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Optical landmarks refer to the supplied 1254px artwork, excluding its rim.
if (-not ('PocketFlowLauncherRaster' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Drawing;
public static class PocketFlowLauncherRaster {
    public static Bitmap Render(Bitmap source, int size, bool adaptive) {
        if (source.Width != 1254 || source.Height != 1254)
            throw new ArgumentException("Review optical landmarks for a changed source.");
        var pixels = new Bitmap(size, size);
        double span = adaptive ? 108.0 : 72.0;
        double start = adaptive ? 0.0 : 18.0;
        for (int y = 0; y < size; y++) for (int x = 0; x < size; x++) {
            // Wallet silhouette: x=300..1022, y=268..987. Its optical anchor
            // (662,655) maps to the system mask center (54dp,54dp).
            double sx = 662 + (start + (x + .5) * span / size - 54) * 722 / 50;
            double sy = 655 + (start + (y + .5) * span / size - 54) * 722 / 50;
            // Extend the original inner blue background to the full layer.
            // Samples stay 8px inside the original rounded tile: no white rim
            // or second rounded frame, and no repainting of the wallet.
            double cx = Math.Clamp(sx, 332, 920), cy = Math.Clamp(sy, 346, 910);
            double dx = sx - cx, dy = sy - cy, length = Math.Sqrt(dx*dx + dy*dy);
            if (length > 250) { sx = cx + dx * 250 / length; sy = cy + dy * 250 / length; }
            int x0 = (int)Math.Floor(sx), y0 = (int)Math.Floor(sy);
            double fx = sx-x0, fy = sy-y0;
            Color a=source.GetPixel(x0,y0), b=source.GetPixel(x0+1,y0),
                  c=source.GetPixel(x0,y0+1), d=source.GetPixel(x0+1,y0+1);
            Func<int,int,int,int,int> mix=(v1,v2,v3,v4) => (int)Math.Round(
                (v1*(1-fx)+v2*fx)*(1-fy)+(v3*(1-fx)+v4*fx)*fy);
            double alpha = 255;
            if (!adaptive) {
                // Apply one antialiased rounded square for Android 24–25.
                double r=size*.2, px=x+.5-Math.Clamp(x+.5,r,size-r),
                    py=y+.5-Math.Clamp(y+.5,r,size-r);
                alpha=255*Math.Clamp(r-Math.Sqrt(px*px+py*py)+.5,0,1);
            }
            pixels.SetPixel(x,y,Color.FromArgb((int)Math.Round(alpha),mix(a.R,b.R,c.R,d.R),
                mix(a.G,b.G,c.G,d.G),mix(a.B,b.B,c.B,d.B)));
        }
        return pixels;
    }
}
'@ -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives
}
$sourcePath = Join-Path $ProjectRoot 'design/app-icon/source.png'
$resources = Join-Path $ProjectRoot 'android/app/src/main/res'
$source = [Drawing.Bitmap]::new($sourcePath)
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
        $bitmap = [PocketFlowLauncherRaster]::Render($source, $size, $target.Directory -eq 'drawable-nodpi')
        try {
            $directory = Join-Path $resources $target.Directory
            New-Item -ItemType Directory -Force -Path $directory | Out-Null
            $name = if ($target.Directory -eq 'drawable-nodpi') { 'pocketflow_launcher_art.png' } else { 'ic_launcher.png' }
            $bitmap.Save((Join-Path $directory $name), [Drawing.Imaging.ImageFormat]::Png)
            Write-Output "$($target.Directory)/$name : ${size}x${size}"
        } finally { $bitmap.Dispose() }
    }
} finally { $source.Dispose() }
