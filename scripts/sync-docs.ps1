$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$docs = Join-Path $root 'docs'
$docsChapters = Join-Path $docs 'chapters'

New-Item -ItemType Directory -Force -Path $docs | Out-Null
New-Item -ItemType Directory -Force -Path $docsChapters | Out-Null

# Copy intro README to docs root
Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination (Join-Path $docs 'README.md') -Force

# Copy core pages
Copy-Item -LiteralPath (Join-Path $root 'characters.md') -Destination (Join-Path $docs 'characters.md') -Force
Copy-Item -LiteralPath (Join-Path $root 'settings.md') -Destination (Join-Path $docs 'settings.md') -Force

# Copy chapters
$srcChapters = Join-Path $root 'chapters'
Get-ChildItem -LiteralPath $srcChapters -Filter *.md | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $docsChapters $_.Name) -Force
}

# Build sidebar with titles extracted from first heading of each chapter
function Get-Title($path) {
  $line = (Get-Content -LiteralPath $path -Encoding UTF8 -TotalCount 1)
  if ($line -match '^#\s*(.+)$') { return $Matches[1] }
  return [System.IO.Path]::GetFileNameWithoutExtension($path)
}

$sb = New-Object System.Collections.Generic.List[string]
$sb.Add("- 目录")
$sb.Add("- [人物志](characters.md)")
$sb.Add("- [世界观与武学系统](settings.md)")
$sb.Add("- 章节")

$chapterFiles = Get-ChildItem -LiteralPath $docsChapters -Filter *.md | Sort-Object Name
foreach ($f in $chapterFiles) {
  $title = Get-Title $f.FullName
  $rel = Join-Path 'chapters' $f.Name
  $sb.Add("- [${title}](${rel})")
}

$sb | Set-Content -Encoding UTF8 (Join-Path $docs '_sidebar.md')

Write-Host "Docs synced to: $docs"
