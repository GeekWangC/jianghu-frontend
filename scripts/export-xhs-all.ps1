param(
  [string]$Root,
  [int]$Dpi = 192,
  [switch]$Overwrite
)

$ErrorActionPreference = 'Stop'

function Resolve-Root {
  param([string]$r)
  if ([string]::IsNullOrWhiteSpace($r)) {
    $scriptDir = $null
    if ($PSScriptRoot) { $scriptDir = $PSScriptRoot }
    elseif ($PSCommandPath) { $scriptDir = (Split-Path -Parent $PSCommandPath) }
    elseif ($MyInvocation.MyCommand.Path) { $scriptDir = (Split-Path -Parent $MyInvocation.MyCommand.Path) }
    else { $scriptDir = (Get-Location).Path }
    return (Split-Path -Parent $scriptDir)
  }
  return (Resolve-Path -LiteralPath $r).Path
}

function Find-Executable {
  param([string[]]$Names, [string[]]$Candidates)
  foreach ($n in $Names) {
    $c = Get-Command $n -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
  }
  foreach ($p in $Candidates) {
    if ($p -and (Test-Path -LiteralPath $p)) { return $p }
  }
  return $null
}

function Find-Converter {
  # Try inkscape
  $ink = Find-Executable @('inkscape','inkscape.com') @(
    (Join-Path $Env:ProgramFiles 'Inkscape\bin\inkscape.com'),
    (Join-Path $Env:ProgramFiles 'Inkscape\bin\inkscape.exe'),
    (Join-Path $Env:ProgramFiles 'Inkscape\inkscape.com'),
    (Join-Path $Env:ProgramFiles 'Inkscape\inkscape.exe'),
    (Join-Path ${Env:ProgramFiles(x86)} 'Inkscape\bin\inkscape.com'),
    (Join-Path ${Env:ProgramFiles(x86)} 'Inkscape\inkscape.com')
  )
  if ($ink) { return @{ Name = 'Inkscape'; Path = $ink; Kind = 'inkscape' } }

  # Try rsvg-convert (librsvg)
  $rsvg = Find-Executable @('rsvg-convert') @()
  if ($rsvg) { return @{ Name = 'rsvg-convert'; Path = $rsvg; Kind = 'rsvg' } }

  # Try ImageMagick
  $magick = Find-Executable @('magick') @()
  if ($magick) { return @{ Name = 'ImageMagick'; Path = $magick; Kind = 'magick' } }

  # Try resvg
  $resvg = Find-Executable @('resvg') @()
  if ($resvg) { return @{ Name = 'resvg'; Path = $resvg; Kind = 'resvg' } }

  # Try Microsoft Edge headless
  $edge = Find-Executable @('msedge','msedge.exe') @(
    (Join-Path $Env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path ${Env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe')
  )
  if ($edge) { return @{ Name = 'Edge'; Path = $edge; Kind = 'edge' } }

  # Try Google Chrome headless
  $chrome = Find-Executable @('chrome','chrome.exe','google-chrome') @(
    (Join-Path $Env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
    (Join-Path ${Env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe')
  )
  if ($chrome) { return @{ Name = 'Chrome'; Path = $chrome; Kind = 'chrome' } }

  return $null
}

function Convert-UnitToPx {
  param([string]$Value, [int]$Dpi)
  if (-not $Value) { return $null }
  $v = $Value.Trim()
  # extract numeric part and unit
  if ($v -match '^(?<n>[-+]?[0-9]*\.?[0-9]+)\s*(?<u>[a-zA-Z%]*)$') {
    $n = [double]$Matches['n']
    $u = $Matches['u'].ToLower()
    switch ($u) {
      '' { return $n } # unitless -> px
      'px' { return $n }
      'mm' { return $n * ($Dpi / 25.4) }
      'cm' { return $n * ($Dpi / 2.54) }
      'in' { return $n * $Dpi }
      'pt' { return $n * ($Dpi / 72.0) }
      'pc' { return $n * ($Dpi / 6.0) } # 1pc = 12pt
      default { return $n }
    }
  }
  return $null
}

function Get-SvgPixelSize {
  param([string]$SvgPath, [int]$Dpi)
  $raw = Get-Content -LiteralPath $SvgPath -Raw -Encoding UTF8
  $w = $null; $h = $null
  $mW = [regex]::Match($raw, '\bwidth\s*=\s*["\'']([^"\'']+)["\'']', 'IgnoreCase')
  $mH = [regex]::Match($raw, '\bheight\s*=\s*["\'']([^"\'']+)["\'']', 'IgnoreCase')
  if ($mW.Success) { $w = Convert-UnitToPx $mW.Groups[1].Value $Dpi }
  if ($mH.Success) { $h = Convert-UnitToPx $mH.Groups[1].Value $Dpi }

  if (-not $w -or -not $h) {
    $mVB = [regex]::Match($raw, '\bviewBox\s*=\s*["\'']([^"\'']+)["\'']', 'IgnoreCase')
    if ($mVB.Success) {
      $parts = $mVB.Groups[1].Value -split '\s+' | Where-Object { $_ -ne '' }
      if ($parts.Length -ge 4) {
        $vw = [double]$parts[2]; $vh = [double]$parts[3]
        if (-not $w) { $w = $vw }
        if (-not $h) { $h = $vh }
      }
    }
  }

  if (-not $w) { $w = 1024 }
  if (-not $h) { $h = 1024 }

  return @{ W = [math]::Ceiling([double]$w); H = [math]::Ceiling([double]$h) }
}

function Get-FileUri {
  param([string]$Path)
  $rp = (Resolve-Path -LiteralPath $Path).Path
  return ([Uri]$rp).AbsoluteUri
}

function Convert-OneSvg {
  param(
    [Parameter(Mandatory=$true)][string]$Svg,
    [Parameter(Mandatory=$true)][string]$Png,
    [Parameter(Mandatory=$true)]$Conv,
    [int]$Dpi = 192,
    [switch]$Overwrite
  )
  if ((-not $Overwrite) -and (Test-Path -LiteralPath $Png)) { return $false }

  $exe = $Conv.Path
  switch ($Conv.Kind) {
    'inkscape' {
      & $exe --export-type=png --export-filename="$Png" --export-dpi=$Dpi "$Svg" | Out-Null
      return $true
    }
    'rsvg' {
      & $exe -f png -o "$Png" -a -d $Dpi -p $Dpi "$Svg" | Out-Null
      return $true
    }
    'magick' {
      & $exe -density $Dpi -background none "$Svg" "$Png" | Out-Null
      return $true
    }
    'resvg' {
      & $exe "$Svg" "$Png" | Out-Null
      return $true
    }
    'edge' {
      $sz = Get-SvgPixelSize -SvgPath $Svg -Dpi $Dpi
      $scale = [math]::Max(1, [math]::Round($Dpi / 96.0, 2))
      $w = [int]([math]::Min(16384, [math]::Ceiling($sz.W * $scale)))
      $h = [int]([math]::Min(16384, [math]::Ceiling($sz.H * $scale)))
      $uri = Get-FileUri -Path $Svg
      & $exe --headless --disable-gpu --hide-scrollbars --window-size=$w,$h --screenshot="$Png" "$uri" | Out-Null
      return (Test-Path -LiteralPath $Png)
    }
    'chrome' {
      $sz = Get-SvgPixelSize -SvgPath $Svg -Dpi $Dpi
      $scale = [math]::Max(1, [math]::Round($Dpi / 96.0, 2))
      $w = [int]([math]::Min(16384, [math]::Ceiling($sz.W * $scale)))
      $h = [int]([math]::Min(16384, [math]::Ceiling($sz.H * $scale)))
      $uri = Get-FileUri -Path $Svg
      & $exe --headless --disable-gpu --hide-scrollbars --window-size=$w,$h --screenshot="$Png" "$uri" | Out-Null
      return (Test-Path -LiteralPath $Png)
    }
    default { throw "Unsupported converter: $($Conv.Kind)" }
  }
}

$root = Resolve-Root $Root
$xhs = Join-Path $root 'xhs'
if (-not (Test-Path -LiteralPath $xhs)) { throw "Not found: $xhs" }

$conv = Find-Converter
if (-not $conv) {
  Write-Error 'No SVG->PNG converter found (Inkscape / rsvg-convert / magick / resvg).'
  Write-Host 'Install one of:'
  Write-Host '  winget install Inkscape.Inkscape'
  Write-Host '  winget install ImageMagick.ImageMagick'
  Write-Host 'Or ensure these tools are in PATH, then retry.'
  exit 2
}

Write-Host ("Using converter: {0} ({1})" -f $conv.Name, $conv.Path)

$chapters = Get-ChildItem -LiteralPath $xhs -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'pages') }
if (-not $chapters) { throw "No chapter dirs found (expect: xhs/<chapter>/pages/*.svg)" }

$total = 0; $done = 0
foreach ($ch in $chapters) {
  $pages = Join-Path $ch.FullName 'pages'
  $pngDir = Join-Path $ch.FullName 'png'
  New-Item -ItemType Directory -Force -Path $pngDir | Out-Null

  $svgs = Get-ChildItem -LiteralPath $pages -Filter *.svg | Sort-Object Name
  foreach ($f in $svgs) {
    $total++
    $png = Join-Path $pngDir ($f.BaseName + '.png')
    $ok = Convert-OneSvg -Svg $f.FullName -Png $png -Conv $conv -Dpi $Dpi -Overwrite:$Overwrite
    if ($ok) { $done++; Write-Host "OK $png" } else { Write-Host "Skip existing $png" }
  }
}

Write-Host ("Done: {0}/{1} files" -f $done, $total)
