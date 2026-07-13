param(
  [Parameter(Mandatory = $true)]
  [string]$SubscriptionId,
  [Parameter(Mandatory = $false)]
  [string]$Location = "koreacentral",
  [Parameter(Mandatory = $false)]
  [string]$Prefix = "cocopau",
  [Parameter(Mandatory = $false)]
  [string]$GoogleClientId = "986841478749-8al2nk1ohe1n5b4rsh5jj58kqpir7j8l.apps.googleusercontent.com"
)

$ErrorActionPreference = "Stop"

function New-RandomSuffix {
  return -join ((97..122) + (48..57) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
}

function Ensure-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name command is required"
  }
}

Ensure-Command "az"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$suffix = New-RandomSuffix

$resourceGroup = "$Prefix-rg-$suffix"
$staticStorage = (($Prefix + "st" + $suffix).ToLower() -replace "[^a-z0-9]", "")
$funcStorage = (($Prefix + "funcst" + $suffix).ToLower() -replace "[^a-z0-9]", "")
$functionApp = "$Prefix-func-$suffix"
$cosmosAccount = "$Prefix-cosmos-$suffix"
$cosmosDb = "cocopau-db"
$cosmosContainer = "users"

Write-Host "Setting subscription"
az account set --subscription $SubscriptionId | Out-Null

Write-Host "Creating resource group: $resourceGroup"
az group create --name $resourceGroup --location $Location --output none

Write-Host "Creating storage for static website: $staticStorage"
az storage account create `
  --name $staticStorage `
  --resource-group $resourceGroup `
  --location $Location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --output none

$staticConn = az storage account show-connection-string `
  --name $staticStorage `
  --resource-group $resourceGroup `
  --query connectionString -o tsv

az storage blob service-properties update `
  --connection-string $staticConn `
  --static-website `
  --index-document index.html `
  --404-document index.html `
  --output none

Write-Host "Creating Cosmos DB account: $cosmosAccount"
az cosmosdb create `
  --name $cosmosAccount `
  --resource-group $resourceGroup `
  --locations regionName=$Location `
  --capabilities EnableServerless `
  --output none

az cosmosdb sql database create `
  --account-name $cosmosAccount `
  --resource-group $resourceGroup `
  --name $cosmosDb `
  --output none

az cosmosdb sql container create `
  --account-name $cosmosAccount `
  --resource-group $resourceGroup `
  --database-name $cosmosDb `
  --name $cosmosContainer `
  --partition-key-path "/id" `
  --output none

$cosmosEndpoint = az cosmosdb show `
  --name $cosmosAccount `
  --resource-group $resourceGroup `
  --query documentEndpoint -o tsv

$cosmosKey = az cosmosdb keys list `
  --name $cosmosAccount `
  --resource-group $resourceGroup `
  --type keys `
  --query primaryMasterKey -o tsv

Write-Host "Creating storage for function app: $funcStorage"
az storage account create `
  --name $funcStorage `
  --resource-group $resourceGroup `
  --location $Location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --output none

Write-Host "Creating function app: $functionApp"
az functionapp create `
  --name $functionApp `
  --resource-group $resourceGroup `
  --storage-account $funcStorage `
  --consumption-plan-location $Location `
  --functions-version 4 `
  --runtime node `
  --runtime-version 24 `
  --output none

az functionapp config appsettings set `
  --name $functionApp `
  --resource-group $resourceGroup `
  --settings `
  "COSMOS_DB_ENDPOINT=$cosmosEndpoint" `
  "COSMOS_DB_KEY=$cosmosKey" `
  "COSMOS_DB_DATABASE=$cosmosDb" `
  "COSMOS_DB_CONTAINER=$cosmosContainer" `
  --output none

Write-Host "Packaging and deploying function code"
$funcDir = Join-Path $root "backend-functions"
$zipPath = Join-Path $env:TEMP "cocopau-functions-$suffix.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $funcDir "*") -DestinationPath $zipPath -Force

az functionapp deployment source config-zip `
  --name $functionApp `
  --resource-group $resourceGroup `
  --src $zipPath `
  --build-remote true `
  --output none

$functionEndpoint = "https://$functionApp.azurewebsites.net/api/users/upsert"
$staticWebEndpoint = az storage account show `
  --name $staticStorage `
  --resource-group $resourceGroup `
  --query "primaryEndpoints.web" -o tsv
$staticWebOrigin = $staticWebEndpoint.TrimEnd("/")

Write-Host "Configuring CORS"
az functionapp cors add `
  --name $functionApp `
  --resource-group $resourceGroup `
  --allowed-origins $staticWebOrigin `
  --output none

Write-Host "Updating frontend config"
$appConfigPath = Join-Path $root "app-config.js"
$appConfigContent = @"
window.COCOPAU_CONFIG = {
  googleClientId: "$GoogleClientId",
  cosmosSyncEndpoint: "$functionEndpoint"
};
"@
Set-Content -Path $appConfigPath -Value $appConfigContent -Encoding UTF8

Write-Host "Uploading frontend files"
az storage blob upload-batch `
  --connection-string $staticConn `
  --destination '$web' `
  --source $root `
  --overwrite `
  --pattern "index.html" `
  --output none

az storage blob upload-batch `
  --connection-string $staticConn `
  --destination '$web' `
  --source $root `
  --overwrite `
  --pattern "app-config.js" `
  --output none

Write-Host ""
Write-Host "Deployment completed"
Write-Host "Static web URL: $staticWebEndpoint"
Write-Host "Google OAuth Authorized JavaScript origins에 추가할 값: $staticWebOrigin"
Write-Host "Function URL: $functionEndpoint"
Write-Host "Resource group: $resourceGroup"
