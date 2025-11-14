# Quick Reference - Authentication Fix

## What happened?
Your Azure subscription has key-based authentication disabled on storage accounts. I've fixed the demo to use Azure AD authentication instead.

## What do you need to do?

### Option 1: Use the Fixed Demo (Recommended)
```powershell
# 1. Login to Azure
az login

# 2. Run setup (it now uses Azure AD)
.\azure-setup.ps1

# 3. Use normally
cd DocIntelDemo
dotnet run upload ..\training-docs
```

**That's it!** Everything else works the same.

### Option 2: Enable Key-Based Auth (Not Recommended)
If you have admin permissions and want to enable key-based auth:

```powershell
az storage account update \
  --name YOUR_STORAGE_ACCOUNT \
  --resource-group YOUR_RESOURCE_GROUP \
  --allow-shared-key-access true
```

## What changed under the hood?

| Component | Before | After |
|-----------|--------|-------|
| PowerShell | `--account-key $key` | `--auth-mode login` |
| C# | `new BlobServiceClient(connectionString)` | `new BlobServiceClient(uri, new DefaultAzureCredential())` |
| Config | Stores connection string | Stores account name only |
| Security | Keys in config files | No secrets in config |

## If you get errors

### "Not authorized"
```powershell
# Wait for role propagation
Start-Sleep -Seconds 30

# Try again
.\azure-setup.ps1
```

### "Need to login"
```powershell
az login
```

### Still stuck?
Check: **AUTHENTICATION_GUIDE.md**

## Benefits of this approach

✅ More secure - no keys to manage  
✅ Works with your subscription's security policies  
✅ Better audit trail  
✅ No behavior change from user perspective  

## Files to read

1. **AUTHENTICATION_FIX.md** - Complete technical details
2. **AUTHENTICATION_GUIDE.md** - Troubleshooting help
3. **README.md** - Updated user guide
4. **QUICKSTART.md** - Quick start with auth info

---

**Ready?** Run `az login` then `.\azure-setup.ps1`
