param(
  [string]$Chapter = '01'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$dir = Join-Path $root ("xhs/" + $Chapter + "/pages")
$out = Join-Path $root ("xhs/" + $Chapter + "/png")
New-Item -ItemType Directory -Force -Path $out | Out-Null

$svgs = Get-ChildItem -LiteralPath $dir -Filter *.svg | Sort-Object Name

# Resolve tools
$ink = $null
foreach ($name in @('inkscape','inkscape.com')) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd) { $ink = $cmd.Source; break }
}
if (-not $ink) {
  $defaultInk = @(
    Join-Path $Env:ProgramFiles 'Inkscape\bin\inkscape.com'),
    (Join-Path $Env:ProgramFiles 'Inkscape\bin\inkscape.exe'),
    (Join-Path $Env:ProgramFiles 'Inkscape\inkscape.com'),
    (Join-Path $Env:ProgramFiles 'Inkscape\inkscape.exe'),
    (Join-Path ${Env:ProgramFiles(x86)} 'Inkscape\bin\inkscape.com'),
    (Join-Path ${Env:ProgramFiles(x86)} 'Inkscape\inkscape.com')
  foreach ($p in $defaultInk) { if (Test-Path $p) { $ink = $p; break } }
}

$rsvg = (Get-Command 'rsvg-convert' -ErrorAction SilentlyContinue)?.Source
$magick = (Get-Command 'magick' -ErrorAction SilentlyContinue)?.Source
$resvg = (Get-Command 'resvg' -ErrorAction SilentlyContinue)?.Source

if ($ink) {
  foreach ($f in $svgs) {
    $png = Join-Path $out ($f.BaseName + '.png')
    & $ink --export-type=png --export-filename="$png" --export-dpi=192 "$($f.FullName)" | Out-Null
    Write-Host "Exported (Inkscape): $png"
  }
} elseif ($rsvg) {
  foreach ($f in $svgs) {
    $png = Join-Path $out ($f.BaseName + '.png')
    & $rsvg -f png -o "$png" -a -d 192 -p 192 "$($f.FullName)" | Out-Null
    Write-Host "Exported (rsvg-convert): $png"
  }
} elseif ($magick) {
  foreach ($f in $svgs) {
    $png = Join-Path $out ($f.BaseName + '.png')
    # -density should precede reading the vector for rasterization DPI
    & $magick -density 192 -background none "$($f.FullName)" "$png" | Out-Null
    Write-Host "Exported (ImageMagick): $png"
  }
} elseif ($resvg) {
  foreach ($f in $svgs) {
    $png = Join-Path $out ($f.BaseName + '.png')
    & $resvg "$($f.FullName)" "$png" | Out-Null
    Write-Host "Exported (resvg): $png"
  }
} else {
  Write-Warning 'No SVG->PNG tool found.'
  Write-Host 'Options:'
  Write-Host '1) Install Inkscape and ensure PATH has inkscape(.com).'
  Write-Host '   winget install Inkscape.Inkscape  或  choco install inkscape'
  Write-Host '2) Or install ImageMagick (magick)'
  Write-Host '   winget install ImageMagick.ImageMagick  或  choco install imagemagick'
  Write-Host '3) Or install librsvg (rsvg-convert) or resvg'
  Write-Host '4) 或使用 VS Code 或浏览器另存为 PNG'
}
