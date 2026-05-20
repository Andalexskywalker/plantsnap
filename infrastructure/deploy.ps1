# ============================================================
# PlantSnap - Azure Infrastructure Deployment Script
# Cria toda a infraestrutura Azure necessária para a aplicação
# Uso: ./infrastructure/deploy.ps1
# ============================================================

param(
    [string]$ResourceGroup    = "plantsnap-rg",
    [string]$Location         = "swedencentral",
    [string]$AppName          = "plantsnap-app",
    [string]$AcrName          = "plantsnapregistry",
    [string]$StorageAccount   = "plantsnapstorage",
    [string]$CosmosAccount    = "plantsnap-cosmos",
    [string]$CosmosDatabase   = "plantsnap",
    [string]$CosmosContainer  = "plants",
    [string]$FunctionAppName  = "plantsnap-functions",
    [string]$FunctionStorage  = "plantsnapfuncstore"
)

Write-Host "========================================" -ForegroundColor Green
Write-Host "  PlantSnap - Deployment de Infraestrutura" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 1. Resource Group
Write-Host "[1/9] A criar Resource Group..." -ForegroundColor Cyan
az group create --name $ResourceGroup --location $Location
Write-Host "      ✅ Resource Group criado." -ForegroundColor Green

# 2. Azure Container Registry
Write-Host "[2/9] A criar Azure Container Registry..." -ForegroundColor Cyan
az acr create `
    --resource-group $ResourceGroup `
    --name $AcrName `
    --sku Basic `
    --admin-enabled true
Write-Host "      ✅ Container Registry criado." -ForegroundColor Green

# 3. Storage Account para Blobs (imagens das plantas)
Write-Host "[3/9] A criar Storage Account para imagens..." -ForegroundColor Cyan
az storage account create `
    --name $StorageAccount `
    --resource-group $ResourceGroup `
    --location $Location `
    --sku Standard_LRS `
    --allow-blob-public-access true

$storageKey = az storage account keys list `
    --account-name $StorageAccount `
    --resource-group $ResourceGroup `
    --query "[0].value" -o tsv

az storage container create `
    --name "plant-images" `
    --account-name $StorageAccount `
    --account-key $storageKey `
    --public-access blob

$storageConnectionString = az storage account show-connection-string `
    --name $StorageAccount `
    --resource-group $ResourceGroup `
    --query connectionString -o tsv

Write-Host "      ✅ Storage Account e Container criados." -ForegroundColor Green

# 4. CosmosDB
Write-Host "[4/9] A criar CosmosDB..." -ForegroundColor Cyan
az cosmosdb create `
    --name $CosmosAccount `
    --resource-group $ResourceGroup `
    --locations regionName=$Location

az cosmosdb sql database create `
    --account-name $CosmosAccount `
    --resource-group $ResourceGroup `
    --name $CosmosDatabase

az cosmosdb sql container create `
    --account-name $CosmosAccount `
    --resource-group $ResourceGroup `
    --database-name $CosmosDatabase `
    --name $CosmosContainer `
    --partition-key-path "/userId"

$cosmosEndpoint = az cosmosdb show `
    --name $CosmosAccount `
    --resource-group $ResourceGroup `
    --query documentEndpoint -o tsv

$cosmosKey = az cosmosdb keys list `
    --name $CosmosAccount `
    --resource-group $ResourceGroup `
    --query primaryMasterKey -o tsv

Write-Host "      ✅ CosmosDB criado." -ForegroundColor Green

# 5. App Service Plan
Write-Host "[5/9] A criar App Service Plan..." -ForegroundColor Cyan
az appservice plan create `
    --name "plantsnap-plan" `
    --resource-group $ResourceGroup `
    --is-linux `
    --sku B1
Write-Host "      ✅ App Service Plan criado." -ForegroundColor Green

# 6. Azure Web App (container)
Write-Host "[6/9] A criar Azure Web App..." -ForegroundColor Cyan
$acrPassword = az acr credential show `
    --name $AcrName `
    --query passwords[0].value -o tsv

az webapp create `
    --resource-group $ResourceGroup `
    --plan "plantsnap-plan" `
    --name $AppName `
    --deployment-container-image-name "$AcrName.azurecr.io/plantsnap:latest"

az webapp config container set `
    --name $AppName `
    --resource-group $ResourceGroup `
    --docker-custom-image-name "$AcrName.azurecr.io/plantsnap:latest" `
    --docker-registry-server-url "https://$AcrName.azurecr.io" `
    --docker-registry-server-user $AcrName `
    --docker-registry-server-password $acrPassword

Write-Host "      ✅ Web App criada." -ForegroundColor Green

# 7. Storage Account para Azure Functions
Write-Host "[7/9] A criar Storage para Functions..." -ForegroundColor Cyan
az storage account create `
    --name $FunctionStorage `
    --resource-group $ResourceGroup `
    --location $Location `
    --sku Standard_LRS
Write-Host "      ✅ Storage para Functions criado." -ForegroundColor Green

# 8. Azure Function App
Write-Host "[8/9] A criar Azure Function App..." -ForegroundColor Cyan
az functionapp create `
    --resource-group $ResourceGroup `
    --consumption-plan-location $Location `
    --runtime python `
    --runtime-version 3.11 `
    --functions-version 4 `
    --name $FunctionAppName `
    --storage-account $FunctionStorage `
    --os-type linux
Write-Host "      ✅ Function App criada." -ForegroundColor Green

# 9. Configurar variáveis de ambiente na Web App
Write-Host "[9/9] A configurar variáveis de ambiente..." -ForegroundColor Cyan
Write-Host "      ⚠️  Adiciona manualmente as seguintes variáveis no Portal Azure ou via az webapp config appsettings set:" -ForegroundColor Yellow
Write-Host "         COSMOS_ENDPOINT      = $cosmosEndpoint" -ForegroundColor White
Write-Host "         COSMOS_KEY           = (ver no Portal Azure)" -ForegroundColor White
Write-Host "         COSMOS_DATABASE      = $CosmosDatabase" -ForegroundColor White
Write-Host "         COSMOS_CONTAINER     = $CosmosContainer" -ForegroundColor White
Write-Host "         STORAGE_CONNECTION_STRING = $storageConnectionString" -ForegroundColor White
Write-Host "         STORAGE_CONTAINER    = plant-images" -ForegroundColor White
Write-Host "         VISION_ENDPOINT      = (Azure Computer Vision endpoint)" -ForegroundColor White
Write-Host "         VISION_KEY           = (Azure Computer Vision key)" -ForegroundColor White
Write-Host "         PLANTID_API_KEY      = (Plant.id API key)" -ForegroundColor White
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✅ Infraestrutura criada com sucesso!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  URL da aplicação: https://$AppName.azurewebsites.net/app" -ForegroundColor Cyan
Write-Host ""
