param(
  [string]$Chapter = '01',
  [string]$MdPath,
  [int]$Dpi = 192,
  [ValidateSet('light','dark')][string]$Theme = 'light',
  [switch]$Overwrite
)

$ErrorActionPreference = 'Stop'

function Resolve-Root {
  $scriptDir = $null
  if ($PSScriptRoot) { $scriptDir = $PSScriptRoot }
  elseif ($PSCommandPath) { $scriptDir = (Split-Path -Parent $PSCommandPath) }
  elseif ($MyInvocation.MyCommand.Path) { $scriptDir = (Split-Path -Parent $MyInvocation.MyCommand.Path) }
  else { $scriptDir = (Get-Location).Path }
  return (Split-Path -Parent $scriptDir)
}

function Find-Executable {
  param([string[]]$Names, [string[]]$Candidates)
  foreach ($n in $Names) {
    $c = Get-Command $n -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
  }
  foreach ($p in $Candidates) { if ($p -and (Test-Path -LiteralPath $p)) { return $p } }
  return $null
}

function Find-Browser {
  # Prefer Edge, then Chrome
  $edge = Find-Executable @('msedge','msedge.exe') @(
    (Join-Path $Env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path ${Env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe')
  )
  if ($edge) { return @{ Name='Edge'; Path=$edge } }
  $chrome = Find-Executable @('chrome','chrome.exe','google-chrome') @(
    (Join-Path $Env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
    (Join-Path ${Env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe')
  )
  if ($chrome) { return @{ Name='Chrome'; Path=$chrome } }
  return $null
}

function To-Paragraphs {
  param([string]$Text)
  $t = $Text -replace "\r\n?","`n"
  # remove leading/trailing blank lines
  $t = ($t.Trim())
  # split by blank lines
  $paras = $t -split "`n\s*`n"
  # strip simple markdown emphasis markers
  $paras = $paras | ForEach-Object { $_ -replace "\*\*?", '' -replace "`"", '' }
  return $paras
}

function Paginate-Text {
  param([string[]]$Paras, [int]$Capacity)
  $pages = @()
  $buf = ''
  foreach ($p in $Paras) {
    $p2 = $p.Trim()
    if ($p2.Length -eq 0) { continue }
    if (($buf.Length + $p2.Length + 2) -le $Capacity) {
      if ($buf.Length -gt 0) { $buf += "`n`n" }
      $buf += $p2
      continue
    }
    # if paragraph too big, split it
    if ($p2.Length -gt $Capacity) {
      $i = 0
      while ($i -lt $p2.Length) {
        $take = [Math]::Min($Capacity, $p2.Length - $i)
        $chunk = $p2.Substring($i, $take)
        if ($buf.Length -gt 0) { $pages += ,$buf; $buf = '' }
        $pages += ,$chunk
        $i += $take
      }
    } else {
      if ($buf.Length -gt 0) { $pages += ,$buf; $buf = '' }
      $pages += ,$p2
    }
  }
  if ($buf.Length -gt 0) { $pages += ,$buf }
  return $pages
}

function Build-PageHtml {
  param([string]$BodyText, [string]$Theme)
  if ($Theme -eq 'dark') {
    $bg = '#0e1116'
    $fg = '#e6edf3'
    $muted = '#9da7b1'
  } else {
    $bg = '#ffffff'
    $fg = '#111111'
    $muted = '#555555'
  }
  @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>page</title>
  <style>
    html,body{margin:0;padding:0;background:$bg;color:$fg}
    .page{width:1080px;height:1440px;display:flex;}
    .inner{margin:84px 72px;display:block;flex:1;font: 36px/1.7 -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', 'Noto Sans CJK SC', 'Source Han Sans SC', sans-serif;}
    .inner p{margin:0 0 24px 0;text-align:justify;word-break:break-word}
    .footer{position:absolute;left:72px;bottom:48px;color:$muted;font-size:24px}
  </style>
  <script>
    // prevent scrollbars, fit to viewport
    window.addEventListener('load', ()=>{ document.body.style.overflow='hidden'; });
  </script>
  </head>
<body>
  <div class="page">
    <div class="inner">
      $BodyText
    </div>
  </div>
</body>
</html>
"@
}

function HtmlEscape([string]$s) {
  return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;')
}

$root = Resolve-Root
$docs = Join-Path $root 'docs\chapters'
if (-not $MdPath) {
  $candidates = Get-ChildItem -LiteralPath $docs -Filter "$Chapter-*.md" | Select-Object -First 1
  if (-not $candidates) { throw "Cannot find markdown for chapter $Chapter under $docs" }
  $MdPath = $candidates.FullName
}
if (-not (Test-Path -LiteralPath $MdPath)) { throw "Markdown file not found: $MdPath" }

$xhs = Join-Path $root "xhs\$Chapter"
$htmlDir = Join-Path $xhs 'pages-full'
$pngDir = Join-Path $xhs 'png-full'
New-Item -ItemType Directory -Force -Path $htmlDir | Out-Null
New-Item -ItemType Directory -Force -Path $pngDir | Out-Null

$raw = Get-Content -LiteralPath $MdPath -Encoding UTF8 -Raw
$paras = To-Paragraphs -Text $raw

# capacity tuning: ~450 CJK chars per 1080x1440 at 36px/1.7 with margins
$capacity = 450
$pages = Paginate-Text -Paras $paras -Capacity $capacity

# Write HTML files
$idx = 1
foreach ($p in $pages) {
  $htmlParas = ($p -split "`n`n") | ForEach-Object { '<p>' + (HtmlEscape $_) + '</p>' }
  $body = [string]::Join("`n", $htmlParas)
  $html = Build-PageHtml -BodyText $body -Theme $Theme
  $name = ('page-{0:D2}.html' -f $idx)
  $outPath = Join-Path $htmlDir $name
  if ($Overwrite -or -not (Test-Path -LiteralPath $outPath)) {
    Set-Content -LiteralPath $outPath -Encoding UTF8 -Value $html
  }
  $idx++
}

# Find browser
$browser = Find-Browser
if (-not $browser) {
  Write-Error 'No Edge/Chrome found for headless screenshots.'
  Write-Host 'Install Microsoft Edge or Google Chrome and retry.'
  exit 2
}
Write-Host ("Using browser: {0} ({1})" -f $browser.Name, $browser.Path)

# DPI to device scale (96dpi base)
$scale = [math]::Max(1, [math]::Round($Dpi / 96.0, 2))
$vw = [int](1080 * $scale)
$vh = [int](1440 * $scale)

# Screenshot each HTML
$htmlFiles = Get-ChildItem -LiteralPath $htmlDir -Filter *.html | Sort-Object Name
$countOk = 0; $count = 0
foreach ($f in $htmlFiles) {
  $count++
  $png = Join-Path $pngDir ([IO.Path]::GetFileNameWithoutExtension($f.Name) + '.png')
  if (-not $Overwrite -and (Test-Path -LiteralPath $png)) { Write-Host "Skip existing $png"; continue }
  # Build a proper file URI for Windows paths (PS5.1-safe)
  $resolvedPath = (Resolve-Path -LiteralPath $f.FullName | Select-Object -ExpandProperty Path)
  $uri = 'file:///' + $resolvedPath.Replace('\','/')
  & $browser.Path --headless --disable-gpu --hide-scrollbars --window-size=$vw,$vh --screenshot="$png" "$uri" | Out-Null
  if (Test-Path -LiteralPath $png) { $countOk++; Write-Host "OK $png" } else { Write-Host "Fail $png" }
}

Write-Host ("Done: {0}/{1} files" -f $countOk, $count)
