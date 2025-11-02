$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$bookPath = Join-Path $root 'book.md'

# Use ASCII-only literals to avoid parser/encoding issues; contents are UTF-8 from files
$title = @(
    '# Jianghu Frontend: Winds at Forty',
    '',
    'Author:',
    '',
    'Note: A wuxia novel in Jin Yong style about a frontend engineer nearing forty.',
    '',
    '---',
    '',
    '## Contents',
    '- Characters',
    '- Settings',
    '- Chapter 1',
    '- Chapter 2',
    '- Chapter 3',
    '- Chapter 4',
    '- Chapter 5',
    '- Chapter 6',
    '- Chapter 7',
    '- Chapter 8 (End)',
    '',
    '---',
    ''
)

$title | Set-Content -Encoding UTF8 $bookPath

$parts = @()
$parts += (Join-Path $root 'characters.md')
$parts += (Join-Path $root 'settings.md')

$chaptersDir = Join-Path $root 'chapters'
$chapterFiles = Get-ChildItem -LiteralPath $chaptersDir -Filter *.md | Sort-Object Name | Select-Object -ExpandProperty FullName
$parts += $chapterFiles

foreach ($path in $parts) {
    if (-not (Test-Path $path)) { throw "Missing part: $path" }
    "`n---`n" | Add-Content -Encoding UTF8 $bookPath
    Get-Content -LiteralPath $path -Encoding UTF8 | Add-Content -Encoding UTF8 $bookPath
}

Write-Host "Created: $bookPath"
