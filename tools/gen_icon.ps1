Add-Type -AssemblyName System.Drawing

$root = $args[0]

$bg = [System.Drawing.ColorTranslator]::FromHtml("#1B1D21")

# Tres bancos de un tajo abierto visto en seccion. Son trapecios, no
# rectangulos: apilados forman un embudo escalonado, que es la silueta que
# se reconoce como mina. Con rectangulos el icono parece un grafico de barras.
# El color se oscurece con la profundidad.
$bands = @(
    @{ top = 0.88; bot = 0.70; color = "#E8B45A" },
    @{ top = 0.70; bot = 0.52; color = "#D89440" },
    @{ top = 0.52; bot = 0.34; color = "#C97B2B" }
)
$bandH = 0.165
$gap   = 0.030

function Draw-Motif($g, $size, $scale) {
    $totalH = ($bandH * 3) + ($gap * 2)
    $cx = $size / 2.0
    $y = ($size / 2.0) - (($totalH * $scale * $size) / 2.0)

    foreach ($b in $bands) {
        $tw = $b.top * $scale * $size
        $bw = $b.bot * $scale * $size
        $h  = $bandH * $scale * $size
        $pts = @(
            (New-Object System.Drawing.PointF([float]($cx - $tw / 2), [float]$y)),
            (New-Object System.Drawing.PointF([float]($cx + $tw / 2), [float]$y)),
            (New-Object System.Drawing.PointF([float]($cx + $bw / 2), [float]($y + $h))),
            (New-Object System.Drawing.PointF([float]($cx - $bw / 2), [float]($y + $h)))
        )
        $color = [System.Drawing.ColorTranslator]::FromHtml($b.color)
        $brush = New-Object System.Drawing.SolidBrush($color)
        $g.FillPolygon($brush, [System.Drawing.PointF[]]$pts)
        $brush.Dispose()
        $y += $h + ($gap * $scale * $size)
    }
}

function New-Icon($path, $size, $withBg, $scale) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    if ($withBg) {
        $b = New-Object System.Drawing.SolidBrush($bg)
        $g.FillRectangle($b, 0, 0, $size, $size)
        $b.Dispose()
    }
    Draw-Motif $g $size $scale
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Output "$path ($size)"
}

# Icono legacy: fondo incluido, motivo al 76% del lienzo.
$legacy = @{ "mdpi" = 48; "hdpi" = 72; "xhdpi" = 96; "xxhdpi" = 144; "xxxhdpi" = 192 }
foreach ($d in $legacy.Keys) {
    New-Icon "$root\mipmap-$d\ic_launcher.png" $legacy[$d] $true 0.76
}

# Capa frontal del icono adaptativo: sin fondo y motivo al 48% del lienzo,
# porque Android recorta hasta el 66% central y ademas anima un zoom.
$adaptive = @{ "mdpi" = 108; "hdpi" = 162; "xhdpi" = 216; "xxhdpi" = 324; "xxxhdpi" = 432 }
foreach ($d in $adaptive.Keys) {
    New-Icon "$root\mipmap-$d\ic_launcher_foreground.png" $adaptive[$d] $false 0.48
}

# Fuente de 1024 para regenerar o retocar a mano en el futuro.
New-Icon "$root\..\icon_source_1024.png" 1024 $true 0.76
