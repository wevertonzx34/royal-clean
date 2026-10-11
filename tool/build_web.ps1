param(
    [switch]$VisualPreview
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Set-Location -LiteralPath $projectRoot
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterPath = if ($flutterCommand) { $flutterCommand.Source } else { 'C:\dev\flutter\bin\flutter.bat' }
if (-not (Test-Path -LiteralPath $flutterPath)) { throw 'Flutter SDK não encontrado.' }
$defines = @{}
if ($VisualPreview) {
    $defines.ROYAL_WEB_VISUAL_PREVIEW = 'true'
} else {
    if ([string]::IsNullOrWhiteSpace($env:ROYAL_WEB_APP_CHECK_SITE_KEY)) {
        throw 'Configure ROYAL_WEB_APP_CHECK_SITE_KEY com a chave pública reCAPTCHA Enterprise cadastrada no App Check.'
    }
    $defines.ROYAL_WEB_APP_CHECK_SITE_KEY = $env:ROYAL_WEB_APP_CHECK_SITE_KEY
}
$defines.ROYAL_INSTITUTIONAL_URL = '/'
foreach ($setting in @('ROYAL_LEGAL_ENTITY', 'ROYAL_LEGAL_CONTACT')) {
    $settingValue = [Environment]::GetEnvironmentVariable($setting)
    if ($settingValue) { $defines[$setting] = $settingValue }
}
New-Item -ItemType Directory -Path '.dart_tool' -Force | Out-Null
$definePath = Join-Path $projectRoot '.dart_tool\royal-web-defines.json'
[IO.File]::WriteAllText($definePath, ($defines | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
& $flutterPath build web --release --base-href /app/ --no-web-resources-cdn "--dart-define-from-file=$definePath"
if ($LASTEXITCODE -ne 0) { throw 'Compilação Web falhou.' }
$metadata = @{project = 'royal-clean-fire'; appId = '1:589116886810:web:727e7e73d00f16d45ba6a3'; visualPreview = [bool]$VisualPreview; baseHref = '/app/'; bundleSha256 = (Get-FileHash -LiteralPath 'build\web\main.dart.js' -Algorithm SHA256).Hash}
[IO.File]::WriteAllText((Join-Path $projectRoot 'build\web\royal-web-release.json'), ($metadata | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
node tool/assemble_web_site.cjs
if ($LASTEXITCODE -ne 0) { throw 'Preparação do site institucional e aplicativo falhou.' }
