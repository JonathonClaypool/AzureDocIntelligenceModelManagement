#Requires -Version 7.0

<#
.SYNOPSIS
    Fixes Document Intelligence access to storage account
.DESCRIPTION
    Grants the Document Intelligence service managed identity access to read from storage
#>

$ErrorActionPreference = "Stop"

Write-Host "=== Fixing Document Intelligence Storage Access ===" -ForegroundColor Cyan
Write-Host ""

# Load config
if (-not (Test-Path "appsettings.json")) {
    Write-Host "✗ appsettings.json not found. Run azure-setup.ps1 first." -ForegroundColor Red
    exit 1
}

$config = Get-Content "appsettings.json" | ConvertFrom-Json
$resourceGroup = $config.ResourceInfo.ResourceGroup
$storageAccount = $config.Storage.AccountName

Write-Host "Resource Group: $resourceGroup" -ForegroundColor Cyan
Write-Host "Storage Account: $storageAccount" -ForegroundColor Cyan  
Write-Host ""

# Find Document Intelligence resources in the resource group
Write-Host "Finding Document Intelligence resources..." -ForegroundColor Yellow
$docIntelResources = az cognitiveservices account list `
    --resource-group $resourceGroup `
    --query "[?kind=='FormRecognizer'].{Name:name, Location:location}" `
    --output json | ConvertFrom-Json

if ($docIntelResources.Count -eq 0) {
    Write-Host "✗ No Document Intelligence resources found in resource group '$resourceGroup'" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($docIntelResources.Count) Document Intelligence resource(s):" -ForegroundColor Green
foreach ($res in $docIntelResources) {
    Write-Host "  • $($res.Name)" -ForegroundColor Cyan
}
Write-Host ""

# Use the first one that looks like the source (contains 'source')
$docIntelName = ($docIntelResources | Where-Object { $_.Name -like '*source*' } | Select-Object -First 1).Name
if ([string]::IsNullOrEmpty($docIntelName)) {
    $docIntelName = $docIntelResources[0].Name
}

Write-Host "Using Document Intelligence resource: $docIntelName" -ForegroundColor Cyan
Write-Host ""

# Enable managed identity
Write-Host "Enabling managed identity for Document Intelligence..." -ForegroundColor Yellow
az cognitiveservices account identity assign `
    --name $docIntelName `
    --resource-group $resourceGroup `
    --output none 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Managed identity enabled" -ForegroundColor Green
} else {
    Write-Host "⚠ Managed identity may already be enabled" -ForegroundColor Yellow
}

# Wait for identity to be ready
Start-Sleep -Seconds 5

# Get the identity
Write-Host "Retrieving managed identity..." -ForegroundColor Yellow
$identity = az cognitiveservices account identity show `
    --name $docIntelName `
    --resource-group $resourceGroup `
    --query principalId `
    --output tsv

if ([string]::IsNullOrEmpty($identity)) {
    Write-Host "✗ Could not retrieve identity" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Identity: $identity" -ForegroundColor Green

# Assign Storage Blob Data Reader role
Write-Host "Assigning Storage Blob Data Reader role..." -ForegroundColor Yellow
az role assignment create `
    --role "Storage Blob Data Reader" `
    --assignee $identity `
    --scope "/subscriptions/$((az account show --query id --output tsv))/resourceGroups/$resourceGroup/providers/Microsoft.Storage/storageAccounts/$storageAccount" `
    --output none 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Role assigned" -ForegroundColor Green
} else {
    Write-Host "⚠ Role may already be assigned" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Waiting for permissions to propagate (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "=== Fix Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Try training again:" -ForegroundColor Yellow
Write-Host "  cd DocIntelDemo" -ForegroundColor Cyan
Write-Host "  dotnet run train InvoiceModel 'v1.0'" -ForegroundColor Cyan
Write-Host ""
