#Requires -Version 7.0

<#
.SYNOPSIS
    Tears down Azure Document Intelligence demo resources
.DESCRIPTION
    Deletes all resources created by azure-setup.ps1
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-docintel-demo",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "=== Azure Document Intelligence Demo Teardown ===" -ForegroundColor Cyan
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

# Check if resource group exists
Write-Host "Checking if resource group exists: $ResourceGroupName..." -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroupName --output tsv

if ($rgExists -eq "false") {
    Write-Host "✓ Resource group does not exist. Nothing to clean up." -ForegroundColor Green
    exit 0
}

# List resources in the group
Write-Host ""
Write-Host "Resources in $ResourceGroupName:" -ForegroundColor Yellow
az resource list --resource-group $ResourceGroupName --query "[].{Name:name, Type:type}" --output table

Write-Host ""

# Confirm deletion
if (-not $Force) {
    Write-Host "⚠ WARNING: This will delete ALL resources in the resource group!" -ForegroundColor Red
    $confirmation = Read-Host "Are you sure you want to continue? (yes/no)"
    
    if ($confirmation -ne "yes") {
        Write-Host "Teardown cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "Deleting resource group: $ResourceGroupName..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Gray

az group delete `
    --name $ResourceGroupName `
    --yes `
    --no-wait

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Resource group deletion initiated" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Deletion is running in the background and may take several minutes to complete." -ForegroundColor Yellow
    Write-Host "You can check the status in the Azure Portal or by running:" -ForegroundColor Yellow
    Write-Host "  az group show --name $ResourceGroupName" -ForegroundColor Cyan
} else {
    Write-Host "✗ Failed to delete resource group" -ForegroundColor Red
    exit 1
}

# Clean up local configuration files
Write-Host ""
Write-Host "Cleaning up local configuration files..." -ForegroundColor Yellow

$filesToDelete = @(".env", "appsettings.json")

foreach ($file in $filesToDelete) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "✓ Deleted $file" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== Teardown Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "All resources have been deleted or are being deleted." -ForegroundColor Cyan
Write-Host ""
