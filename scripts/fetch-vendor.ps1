$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$vendor = Join-Path $root 'docs/vendor'
New-Item -ItemType Directory -Force -Path $vendor | Out-Null

function Get-FirstAvailable($urls, $outPath){
  foreach($u in $urls){
    try{
      Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20 -OutFile $outPath
      if((Get-Item $outPath).Length -gt 1024){ return $true }
    }catch{ }
  }
  return $false
}

$jsPath = Join-Path $vendor 'docsify.min.js'
$cssPath = Join-Path $vendor 'docsify-theme-vue.css'
$markedPath = Join-Path $vendor 'marked.min.js'

$okJs = Get-FirstAvailable @(
  'https://cdn.jsdelivr.net/npm/docsify@4/lib/docsify.min.js',
  'https://unpkg.com/docsify@4/lib/docsify.min.js'
) $jsPath

$okCss = Get-FirstAvailable @(
  'https://cdn.jsdelivr.net/npm/docsify@4/lib/themes/vue.css',
  'https://unpkg.com/docsify@4/lib/themes/vue.css'
) $cssPath

if(-not $okJs -or -not $okCss){
  Write-Warning 'Failed to fetch some vendor assets. Check network or fetch manually.'
} else {
  Write-Host "Vendor assets saved to: $vendor"
}

$okMarked = Get-FirstAvailable @(
  'https://cdn.jsdelivr.net/npm/marked/marked.min.js',
  'https://unpkg.com/marked/marked.min.js'
) $markedPath
if($okMarked){ Write-Host 'Marked saved.' } else { Write-Warning 'Failed to fetch marked.min.js' }
