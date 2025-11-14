# Quick Start Guide

## 1. Prerequisites Check

Ensure you have:
- [ ] Azure CLI installed (`az --version`)
- [ ] **Logged into Azure** (`az login`) - **IMPORTANT!**
- [ ] .NET 8.0 SDK or later (`dotnet --version`)
- [ ] PowerShell 7.0+ (`$PSVersionTable.PSVersion`)

**Note:** This demo uses Azure AD authentication. Make sure you run `az login` before proceeding.

## 2. Initial Setup (5 minutes)

```powershell
# Run the setup script
.\azure-setup.ps1

# This creates:
# - Resource group
# - Storage account
# - 2 Document Intelligence resources (source + target)
# - Configuration files
```

## 3. Prepare Training Data (2 minutes)

### Important: File Format Requirements

Document Intelligence requires **PDF, JPEG, PNG, TIFF, or BMP files**.

### Option A: Use Provided Sample Data (Recommended)

The repository includes sample form images in the `SampleTrainingData/` folder:

```powershell
# Verify sample images exist
dir SampleTrainingData
# Shows 5 Form images with labels and OCR JSON files
```

### Option B: Use Your Own Documents

```powershell
# Create a folder with at least 5 PDF or image documents
mkdir my-training-docs

# Copy your documents to this folder
# Requirements:
# - PDF, JPEG, PNG, TIFF, or BMP format
# - At least 5 DIFFERENT documents (not copies)
# - Similar structure/type (all invoices, all forms, etc.)
# - Clear, scannable quality
```

## 4. Run the Demo

### Clean Container (Optional First Step)
```powershell
cd DocIntelDemo

# Remove any old files from previous runs
dotnet run clean-container
```

### Upload Training Documents
```powershell
# Using downloaded samples
dotnet run upload ..\SampleTrainingData

# Or using your own data
dotnet run upload ..\my-training-docs
```

### Train Your First Model
```powershell
dotnet run train InvoiceModel "First version of invoice model"
```
Wait for training to complete (typically 2-5 minutes).

### List Registered Models
```powershell
dotnet run list-models
```

### Train a Second Version
```powershell
# Upload updated or additional documents
dotnet run upload ..\training-docs-v2

# Train new version (automatically becomes v2.0)
dotnet run train InvoiceModel "Improved accuracy version"
```

### Get Model ID
```powershell
# Get current active model ID
dotnet run get-model InvoiceModel

# Get specific version
dotnet run get-model InvoiceModel 1.0
```

### Switch Between Versions
```powershell
# Set version 1.0 as active
dotnet run set-active InvoiceModel 1.0

# Set version 2.0 as active
dotnet run set-active InvoiceModel 2.0
```

### Copy Model to Different Resource
```powershell
# Copy current active version to target resource
dotnet run copy-model InvoiceModel

# Copy specific version
dotnet run copy-model InvoiceModel 1.0
```

### Analyze a Document
```powershell
# Use the active model version to analyze a document
dotnet run analyze InvoiceModel test-invoice.pdf
```

### List Remote Models
```powershell
# View all models in Azure
dotnet run list-remote
```

## 5. Understanding the Model Registry

The demo maintains a local `model-registry.json` file that maps:
- **Friendly names** (e.g., "InvoiceModel") → **Azure Model IDs** (e.g., "abc-123-def")
- **Versions** of each model
- **Active version** for each model

This allows you to:
1. Use easy-to-remember model names
2. Track multiple versions of the same model
3. Switch between versions without remembering GUIDs
4. Maintain a version history

## 6. Key Concepts Demonstrated

### Model Versioning
Each time you train with the same model name, a new version is created:
- v1.0 → First training
- v2.0 → Second training
- v3.0 → Third training, etc.

### Active Version
The "active" version is used when you:
- Get a model ID without specifying version
- Analyze documents with the model
- Copy the model to another resource

### Model Migration
The copy operation demonstrates moving models between Document Intelligence resources:
- Useful for dev → test → prod promotion
- Useful for regional deployments
- Useful for backup/disaster recovery

## 7. Demo Flow for Client

1. **Show empty registry**: `dotnet run list-models`
2. **Upload documents**: `dotnet run upload training-docs`
3. **Train model**: `dotnet run train InvoiceModel "Initial version"`
4. **Show registered model**: `dotnet run list-models`
5. **Get model ID**: `dotnet run get-model InvoiceModel`
6. **Train v2**: `dotnet run train InvoiceModel "Updated version"`
7. **Show versions**: `dotnet run list-models`
8. **Switch to v1**: `dotnet run set-active InvoiceModel 1.0`
9. **Copy to target**: `dotnet run copy-model InvoiceModel`
10. **Analyze document**: `dotnet run analyze InvoiceModel test.pdf`

## 8. Cleanup

When done with the demo:
```powershell
cd ..
.\azure-teardown.ps1
```

This removes all Azure resources and local configuration files.

## 9. Troubleshooting

### "Not logged in to Azure"
```powershell
az login
az account set --subscription "Your Subscription Name"
```

### "This request is not authorized" (403 error)
This is a network/authentication issue. The demo uses Azure AD authentication. Ensure:
1. You're logged in: `az login`
2. Network access is enabled (setup script handles this)
3. Role propagation (wait 30 seconds after setup, then retry)

If it persists:
```powershell
# Manually verify/assign the role
$userId = az ad signed-in-user show --query id --output tsv
$storageId = az storage account show --name YOUR_STORAGE --resource-group rg-docintel-demo --query id --output tsv
az role assignment create --role "Storage Blob Data Contributor" --assignee $userId --scope $storageId
```

### "Training failed - TrainingContentMissing"
This means Document Intelligence can't find valid training files. Common causes:
- ❌ **Wrong file format**: Ensure files are PDF or image files
- ❌ **Not enough files**: Need at least 5 documents
- ❌ **Duplicate files**: Each document must be unique
- ❌ **Empty container**: Forgot to upload files

**Solution:**
1. Ensure you have 5+ PDF or image files
2. Run `dotnet run clean-container` to start fresh
3. Run `dotnet run upload ..\SampleTrainingData`
4. Try training again

When you run the train command, it will show you which files are in the container and if they're supported formats.

### "allowSharedKeyAccess: false" or Policy Messages
**This is OK!** The demo works with Azure AD authentication only. Shared key access is not required and may be blocked by your organization's policies. This is actually the recommended secure approach.

### "Training failed" (other reasons)
- Ensure documents have similar structure
- Check Azure quota limits
- Verify both resources are in the same region

### "Model not found in registry"
- Check spelling of model name
- Run `dotnet run list-models` to see registered models
- Re-train if registry was deleted

### "Build failed"
```powershell
cd DocIntelDemo
dotnet restore
dotnet build
```

## 10. Cost Considerations

- **Training**: ~$0.50 per model (varies by region)
- **Analysis**: ~$0.001-0.01 per page (varies by model type)
- **Storage**: Minimal (<$1/month for demo)

**Remember to run teardown script when done to avoid ongoing charges!**

## Next Steps

- Review `README.md` for detailed documentation
- Check `TRAINING_DOCUMENTS.md` for document requirements
- Explore the source code in `DocIntelDemo/` folder
- Try with your own document types
