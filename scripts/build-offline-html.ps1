$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$book = Join-Path $root 'book.md'
if(-not (Test-Path $book)){ throw 'book.md not found. Run scripts/build-book.ps1 first.' }
$out = Join-Path $root 'docs/book.html'

$md = Get-Content -LiteralPath $book -Encoding UTF8 -Raw
$mdJs = (ConvertTo-Json -InputObject $md -Compress)

$html = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>江湖前端：风起四十（离线版）</title>
  <link rel="icon" href="assets/cover.svg">
  <link rel="stylesheet" href="styles.css" />
  <style>
    body{background:#0e1116;color:#e6edf3}
    main{max-width:900px;margin:0 auto;padding:24px 18px}
    h1,h2,h3{color:#e6edf3}
    a{color:#1f6feb}
    pre{background:#0b1220;padding:12px;border-radius:6px;overflow:auto}
  </style>
</head>
<body>
  <main>
    <h1>江湖前端：风起四十（离线单页）</h1>
    <p><a href="index.html">返回站点首页</a></p>
    <div id="content">加载中…</div>
  </main>
  <script src="vendor/marked.min.js"></script>
  <script>
    const md = $mdJs;
    document.getElementById('content').innerHTML = marked.parse(md);
  </script>
</body>
</html>
"@

Set-Content -LiteralPath $out -Encoding UTF8 -Value $html
Write-Host "Offline HTML created: $out"

