param([string]$Channel = 'royal-site-review')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')))
if ($Channel -notmatch '^[a-z0-9][a-z0-9-]{0,39}$' -or $Channel -eq 'live') {
    throw 'Use um nome de canal temporário válido; live não é permitido neste script.'
}
foreach ($artifact in @('index.html', 'app\index.html', 'app\flutter_bootstrap.js', 'app\main.dart.js', 'royal-web-release.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path 'build\site' $artifact))) {
        throw "Artefato ausente: $artifact. Execute tool/build_web.ps1 primeiro."
    }
}
$metadata = Get-Content -LiteralPath 'build\site\royal-web-release.json' -Raw | ConvertFrom-Json
if ($metadata.project -ne 'royal-clean-fire' -or $metadata.siteLayout -ne 'institutional-root-flutter-app' -or $metadata.bundleSha256 -ne (Get-FileHash -LiteralPath 'build\site\app\main.dart.js' -Algorithm SHA256).Hash) {
    throw 'Metadados da compilação não correspondem ao bundle. Recompile antes de publicar.'
}
node -e "const {scan}=require('./tool/check_secrets.cjs');const r=scan(require('node:path').resolve('build/site'));console.log(JSON.stringify(r));if(r.findings.length)process.exit(1)"
if ($LASTEXITCODE -ne 0) { throw 'Verificação dos artefatos Web falhou.' }
node tool/firebase_safe.cjs hosting:channel:deploy $Channel --expires 7d --no-authorized-domains --project royal-clean-fire
if ($LASTEXITCODE -ne 0) { throw 'Publicação temporária falhou.' }
