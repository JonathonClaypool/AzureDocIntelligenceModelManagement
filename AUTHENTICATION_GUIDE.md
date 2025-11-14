# Authentication Setup Guide

This demo uses **Azure AD (Entra ID) authentication** instead of storage account keys for better security.

## Why Azure AD Authentication?

Many Azure subscriptions have **key-based authentication disabled** for security compliance. This demo uses:
- **DefaultAzureCredential** for C# application
- **Azure CLI authentication** for PowerShell scripts

## Prerequisites

### 1. Azure CLI Login

Ensure you're logged in to Azure CLI:

```powershell
# Login
az login

# Verify
az account show

# Set subscription if needed
az account set --subscription "Your Subscription Name"
```

### 2. Required Permissions

Your Azure account needs the following roles:
- **Contributor** on the resource group (or subscription)
- **Storage Blob Data Contributor** on the storage account (automatically assigned by setup script)

## How It Works

### Setup Script (`azure-setup.ps1`)

1. Creates storage account
2. **Automatically assigns** "Storage Blob Data Contributor" role to you
3. Uses `--auth-mode login` for all storage operations
4. Waits 10 seconds for role propagation

### C# Application

Uses `DefaultAzureCredential` which tries authentication in this order:
1. **Environment variables** (if set)
2. **Azure CLI** (uses your `az login` credentials) ← Most common in development
3. **Managed Identity** (when running in Azure)
4. **Visual Studio** credentials
5. **Visual Studio Code** credentials
6. **Azure PowerShell** credentials

## Troubleshooting

### Issue: "Role assignment failed"

**Symptoms:**
```
⚠ Role assignment may have failed (might already exist)
```

**Fix:**
This warning is usually harmless. The role might already be assigned. If container creation succeeds, you can ignore this warning.

### Issue: "This request is not authorized"

**Symptoms:**
```
This request is not authorized to perform this operation using this permission
```

**Fix:**
```powershell
# Wait a bit longer for role propagation
Start-Sleep -Seconds 30

# Try running the command again
az storage container create --name training-data --account-name YOUR_ACCOUNT --auth-mode login
```

### Issue: "DefaultAzureCredential failed to retrieve a token"

**Symptoms:**
```
DefaultAzureCredential failed to retrieve a token from the included credentials
```

**Fix:**
```powershell
# Ensure you're logged in
az login

# Verify your identity
az account show

# If using multiple tenants
az login --tenant "your-tenant-id"
```

### Issue: "Need re-authentication"

**Symptoms:**
```
Interactive authentication is needed. Please run 'az login'
```

**Fix:**
```powershell
# Re-login
az login

# Then re-run your command
```

## Manual Role Assignment (if needed)

If the automatic role assignment fails, you can assign it manually:

```powershell
# Get your user ID
$userId = az ad signed-in-user show --query id --output tsv

# Get storage account resource ID
$storageId = az storage account show `
    --name YOUR_STORAGE_ACCOUNT `
    --resource-group YOUR_RESOURCE_GROUP `
    --query id `
    --output tsv

# Assign role
az role assignment create `
    --role "Storage Blob Data Contributor" `
    --assignee $userId `
    --scope $storageId
```

## Alternative: Enable Key-Based Authentication

If you have permission and prefer key-based authentication:

### Azure Portal
1. Go to your Storage Account
2. Navigate to **Configuration**
3. Under **Allow storage account key access**, select **Enabled**
4. Click **Save**

### Azure CLI
```powershell
az storage account update `
    --name YOUR_STORAGE_ACCOUNT `
    --resource-group YOUR_RESOURCE_GROUP `
    --allow-shared-key-access true
```

Then use the old version of the scripts (with storage keys).

## Best Practices

✅ **Recommended**: Use Azure AD authentication (current implementation)
- No secrets in code or config files
- Uses your Azure identity
- Better audit trail
- Follows least-privilege principle

❌ **Not Recommended**: Storage account keys
- Keys provide full access to storage account
- Difficult to rotate
- Can be accidentally committed to source control

## Testing Your Setup

After running `azure-setup.ps1`, test authentication:

```powershell
cd DocIntelDemo

# This should work if authentication is set up correctly
dotnet run upload ..\training-docs
```

If this succeeds, authentication is working properly!

## Additional Resources

- [Azure Storage authentication](https://learn.microsoft.com/azure/storage/common/authorize-data-access)
- [DefaultAzureCredential](https://learn.microsoft.com/dotnet/api/azure.identity.defaultazurecredential)
- [Azure RBAC roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)
