#Requires -Version 7.0

<#
.SYNOPSIS
    Sets up Azure Document Intelligence demo resources
.DESCRIPTION
    Creates resource groups, storage accounts, and Document Intelligence resources for training and migration demo
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-docintel-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$SourceDocIntelName = "docintel-source-$(Get-Random -Maximum 9999)",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetDocIntelName = "docintel-target-$(Get-Random -Maximum 9999)",
    
    [Parameter(Mandatory=$false)]
    [string]$StorageAccountName = "stdocintel$(Get-Random -Maximum 9999)",
    
    [Parameter(Mandatory=$false)]
    [string]$ContainerName = "training-data"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Azure Document Intelligence Demo Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check if logged in to Azure
Write-Host "Checking Azure login status..." -ForegroundColor Yellow
try {
    $account = az account show 2>$null | ConvertFrom-Json
    Write-Host "✓ Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "✓ Subscription: $($account.name)" -ForegroundColor Green
} catch {
    Write-Host "✗ Not logged in to Azure. Please run 'az login' first." -ForegroundColor Red
    exit 1
}

Write-Host ""

# Create Resource Group
Write-Host "Creating resource group: $ResourceGroupName..." -ForegroundColor Yellow
az group create `
    --name $ResourceGroupName `
    --location $Location `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Resource group created" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to create resource group" -ForegroundColor Red
    exit 1
}

# Create Storage Account
Write-Host "Creating storage account: $StorageAccountName..." -ForegroundColor Yellow
az storage account create `
    --name $StorageAccountName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --sku Standard_LRS `
    --kind StorageV2 `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Storage account created" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to create storage account" -ForegroundColor Red
    exit 1
}

# Get current user for RBAC assignment
Write-Host "Getting current user information..." -ForegroundColor Yellow
$currentUser = az ad signed-in-user show --query id --output tsv

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ User information retrieved" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to retrieve user information" -ForegroundColor Red
    exit 1
}

# Assign Storage Blob Data Contributor role to current user
Write-Host "Assigning Storage Blob Data Contributor role..." -ForegroundColor Yellow
az role assignment create `
    --role "Storage Blob Data Contributor" `
    --assignee $currentUser `
    --scope "/subscriptions/$((az account show --query id --output tsv))/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName" `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Role assigned" -ForegroundColor Green
} else {
    Write-Host "⚠ Role assignment may have failed (might already exist)" -ForegroundColor Yellow
}

# Wait a moment for role assignment to propagate
Write-Host "Waiting for role assignment to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Create blob container using auth mode login
Write-Host "Creating blob container: $ContainerName..." -ForegroundColor Yellow
az storage container create `
    --name $ContainerName `
    --account-name $StorageAccountName `
    --auth-mode login `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Container created" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to create container" -ForegroundColor Red
    exit 1
}

# Enable CORS for storage account (needed for Document Intelligence)
Write-Host "Configuring CORS for storage account..." -ForegroundColor Yellow
az storage cors add `
    --services b `
    --methods GET POST PUT DELETE HEAD OPTIONS `
    --origins "*" `
    --allowed-headers "*" `
    --exposed-headers "*" `
    --max-age 200 `
    --account-name $StorageAccountName `
    --only-show-errors `
    2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ CORS configured" -ForegroundColor Green
} else {
    Write-Host "⚠ CORS configuration skipped (requires additional permissions or already configured)" -ForegroundColor Yellow
}

# Create Source Document Intelligence Resource
Write-Host "Creating source Document Intelligence resource: $SourceDocIntelName..." -ForegroundColor Yellow
az cognitiveservices account create `
    --name $SourceDocIntelName `
    --resource-group $ResourceGroupName `
    --kind FormRecognizer `
    --sku S0 `
    --location $Location `
    --yes `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Source Document Intelligence resource created" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to create source Document Intelligence resource" -ForegroundColor Red
    exit 1
}

# Create Target Document Intelligence Resource (for migration)
Write-Host "Creating target Document Intelligence resource: $TargetDocIntelName..." -ForegroundColor Yellow
az cognitiveservices account create `
    --name $TargetDocIntelName `
    --resource-group $ResourceGroupName `
    --kind FormRecognizer `
    --sku S0 `
    --location $Location `
    --yes `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Target Document Intelligence resource created" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to create target Document Intelligence resource" -ForegroundColor Red
    exit 1
}

# Grant Document Intelligence managed identity access to storage
Write-Host "Granting Document Intelligence access to storage account..." -ForegroundColor Yellow

# Get the Document Intelligence resource identity
$docIntelIdentity = az cognitiveservices account identity show `
    --name $SourceDocIntelName `
    --resource-group $ResourceGroupName `
    --query principalId `
    --output tsv 2>$null

if ([string]::IsNullOrEmpty($docIntelIdentity)) {
    Write-Host "Enabling managed identity for Document Intelligence..." -ForegroundColor Yellow
    az cognitiveservices account identity assign `
        --name $SourceDocIntelName `
        --resource-group $ResourceGroupName `
        --output none
    
    Start-Sleep -Seconds 5
    
    $docIntelIdentity = az cognitiveservices account identity show `
        --name $SourceDocIntelName `
        --resource-group $ResourceGroupName `
        --query principalId `
        --output tsv
}

if (-not [string]::IsNullOrEmpty($docIntelIdentity)) {
    # Assign Storage Blob Data Reader role to Document Intelligence
    az role assignment create `
        --role "Storage Blob Data Reader" `
        --assignee $docIntelIdentity `
        --scope "/subscriptions/$((az account show --query id --output tsv))/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName" `
        --output none 2>$null
    
    Write-Host "✓ Document Intelligence granted storage access" -ForegroundColor Green
} else {
    Write-Host "⚠ Could not configure Document Intelligence identity (will rely on SAS tokens)" -ForegroundColor Yellow
}

Write-Host "Waiting for permissions to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Get endpoints and keys
Write-Host ""
Write-Host "Retrieving resource endpoints and keys..." -ForegroundColor Yellow

$sourceEndpoint = az cognitiveservices account show `
    --name $SourceDocIntelName `
    --resource-group $ResourceGroupName `
    --query "properties.endpoint" `
    --output tsv

$sourceKey = az cognitiveservices account keys list `
    --name $SourceDocIntelName `
    --resource-group $ResourceGroupName `
    --query "key1" `
    --output tsv

$targetEndpoint = az cognitiveservices account show `
    --name $TargetDocIntelName `
    --resource-group $ResourceGroupName `
    --query "properties.endpoint" `
    --output tsv

$targetKey = az cognitiveservices account keys list `
    --name $TargetDocIntelName `
    --resource-group $ResourceGroupName `
    --query "key1" `
    --output tsv

$storageConnectionString = az storage account show-connection-string `
    --name $StorageAccountName `
    --resource-group $ResourceGroupName `
    --query "connectionString" `
    --output tsv

# Generate SAS token for the container (valid for 30 days)
Write-Host "Generating SAS token for storage access..." -ForegroundColor Yellow
$sasExpiry = (Get-Date).AddDays(30).ToString("yyyy-MM-ddTHH:mm:ssZ")
$containerSas = az storage container generate-sas `
    --account-name $StorageAccountName `
    --name $ContainerName `
    --permissions racwdl `
    --expiry $sasExpiry `
    --auth-mode login `
    --as-user `
    --output tsv

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ SAS token generated" -ForegroundColor Green
} else {
    Write-Host "⚠ SAS token generation failed, using connection string only" -ForegroundColor Yellow
    $containerSas = ""
}

# Create .env file for the demo application
Write-Host ""
Write-Host "Creating .env file with configuration..." -ForegroundColor Yellow

$envContent = @"
# Azure Document Intelligence Demo Configuration
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Source Document Intelligence Resource
SOURCE_ENDPOINT=$sourceEndpoint
SOURCE_KEY=$sourceKey

# Target Document Intelligence Resource (for migration)
TARGET_ENDPOINT=$targetEndpoint
TARGET_KEY=$targetKey

# Storage Account (using Azure AD authentication)
STORAGE_ACCOUNT_NAME=$StorageAccountName
STORAGE_CONTAINER_NAME=$ContainerName
STORAGE_CONTAINER_SAS=$containerSas

# Resource Information
RESOURCE_GROUP=$ResourceGroupName
LOCATION=$Location
"@

$envContent | Out-File -FilePath ".env" -Encoding UTF8 -NoNewline

Write-Host "✓ Configuration saved to .env file" -ForegroundColor Green

# Create appsettings.json for C# application
Write-Host "Creating appsettings.json for C# demo..." -ForegroundColor Yellow

$appSettingsContent = @"
{
  "DocumentIntelligence": {
    "Source": {
      "Endpoint": "$sourceEndpoint",
      "Key": "$sourceKey"
    },
    "Target": {
      "Endpoint": "$targetEndpoint",
      "Key": "$targetKey"
    }
  },
  "Storage": {
    "AccountName": "$StorageAccountName",
    "ContainerName": "$ContainerName",
    "UseAzureAdAuth": true
  },
  "ResourceInfo": {
    "ResourceGroup": "$ResourceGroupName",
    "Location": "$Location"
  }
}
"@

$appSettingsContent | Out-File -FilePath "appsettings.json" -Encoding UTF8

Write-Host "✓ appsettings.json created" -ForegroundColor Green

# Display summary
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "Location: $Location" -ForegroundColor Cyan
Write-Host ""
Write-Host "Source Document Intelligence:" -ForegroundColor Cyan
Write-Host "  Name: $SourceDocIntelName"
Write-Host "  Endpoint: $sourceEndpoint"
Write-Host ""
Write-Host "Target Document Intelligence:" -ForegroundColor Cyan
Write-Host "  Name: $TargetDocIntelName"
Write-Host "  Endpoint: $targetEndpoint"
Write-Host ""
Write-Host "Storage Account:" -ForegroundColor Cyan
Write-Host "  Name: $StorageAccountName"
Write-Host "  Container: $ContainerName"
Write-Host ""
Write-Host "Configuration files created:" -ForegroundColor Green
Write-Host "  - .env"
Write-Host "  - appsettings.json"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Upload training documents to the storage container"
Write-Host "  2. Run the C# demo application to train and manage models"
Write-Host "  3. Use 'azure-teardown.ps1' to clean up resources when done"
Write-Host ""
