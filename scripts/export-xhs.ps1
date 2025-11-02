$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$dir = Join-Path $root 'xhs/01/pages'
$out = Join-Path $root 'xhs/01/png'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$svgs = Get-ChildItem -LiteralPath $dir -Filter *.svg | Sort-Object Name

$ink = Get-Command inkscape -ErrorAction SilentlyContinue
if ($ink) {
  foreach ($f in $svgs) {
    $png = Join-Path $out ($f.BaseName + '.png')
    & $ink --export-type=png --export-filename=$png --export-dpi=192 $f.FullName | Out-Null
    Write-Host "Exported: $png"
  }
} else {
  Write-Warning 'Inkscape not found. You can export SVG->PNG via:'
  Write-Host '1) VS Code extension or browser另存为PNG'
  Write-Host '2) Install Inkscape: https://inkscape.org'
  Write-Host '3) Or use resvg/cairosvg tools'
}

