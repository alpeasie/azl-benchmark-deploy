param(
    [string]$DeploymentToken = $Env:AZURE_STATIC_WEB_APPS_API_TOKEN,
    [string]$Environment = "production",
    [switch]$Build
)

if (-not $DeploymentToken) {
    Write-Error "Deployment token not provided. Set AZURE_STATIC_WEB_APPS_API_TOKEN or pass -DeploymentToken."; exit 1
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$docsRoot = Join-Path $repoRoot 'azure_jumpstart_localbox'

if ($Build) {
    Write-Host "Building MkDocs site..." -ForegroundColor Cyan
    Push-Location $docsRoot
    pip install -r requirements.txt | Out-Null
    mkdocs build --strict
    Pop-Location
}

$sitePath = Join-Path $docsRoot 'site'
if (-not (Test-Path $sitePath)) { Write-Error "Built site folder not found at $sitePath. Run with -Build."; exit 1 }

if (-not (Get-Command swa -ErrorAction SilentlyContinue)) {
    Write-Host "Installing SWA CLI globally (requires Node.js)..." -ForegroundColor Yellow
    npm install -g @azure/static-web-apps-cli | Out-Null
}

Write-Host "Deploying to Azure Static Web Apps ($Environment)..." -ForegroundColor Cyan
 & swa deploy $sitePath --deployment-token $DeploymentToken --env $Environment
if ($LASTEXITCODE -ne 0) { Write-Error "SWA deploy failed with code $LASTEXITCODE"; exit $LASTEXITCODE }
Write-Host "Deployment complete." -ForegroundColor Green