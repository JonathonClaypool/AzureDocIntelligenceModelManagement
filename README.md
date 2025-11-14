# Azure Document Intelligence Demo

This demo demonstrates how to train custom Document Intelligence models, manage model versions, and copy models between resources.

## Prerequisites

- Azure subscription
- Azure CLI installed and configured
- .NET 8.0 SDK or later
- PowerShell 7.0 or later
- **Logged in to Azure**: Run `az login` before starting

## Authentication

This demo uses **Azure AD (Entra ID) authentication** with managed identities for secure, keyless access to Azure resources. The setup script automatically:
- Enables public network access on storage (required for Document Intelligence service)
- Assigns necessary RBAC roles
- Configures managed identity for Document Intelligence to access storage

See [AUTHENTICATION_GUIDE.md](AUTHENTICATION_GUIDE.md) for details.

> **Note**: If your Azure subscription has policies blocking shared key access, that's fine! This demo works with Azure AD authentication only.

## Setup

### 1. Run Setup Script

Execute the setup script to create all required Azure resources:

```powershell
.\azure-setup.ps1
```

This will create:
- Resource group
- Storage account with blob container
- Source Document Intelligence resource
- Target Document Intelligence resource (for model migration)
- Configuration files (`appsettings.json` and `.env`)

Optional parameters:
```powershell
.\azure-setup.ps1 -Location "westus" -ResourceGroupName "my-custom-rg"
```

### 2. Prepare Training Documents

**Important**: Document Intelligence requires **PDF, JPEG, PNG, TIFF, or BMP files** for training.

**Option A: Use Provided Sample Data (Recommended)**

The repository includes sample training images in the `SampleTrainingData/` folder:

```powershell
# Sample form images are ready to use!
dir SampleTrainingData
# Shows 5 Form images with labels and OCR JSON files
```

**Option B: Use Your Own Documents**

Create a folder with at least 5 documents for training. Documents should be:
- **PDF, JPEG, PNG, TIFF, or BMP format**
- Similar structure (e.g., invoices, forms, receipts)
- At least 5 **different** documents (not copies of the same file)
- Scannable quality with clear text

Example:
```
my-training-docs/
  ├── invoice1.pdf
  ├── invoice2.pdf
  ├── invoice3.pdf
  ├── invoice4.pdf
  └── invoice5.pdf
```

## Usage

### Clean Container (Optional)

If you need to remove all files from the storage container:

```powershell
cd DocIntelDemo
dotnet run clean-container
```

### Upload Training Documents

Upload your training documents to Azure Blob Storage:

```powershell
cd DocIntelDemo

# Upload sample data
dotnet run upload ..\SampleTrainingData

# Or upload your own documents
dotnet run upload ..\my-training-docs
```

### Train a Model

Train a custom Document Intelligence model:

```powershell
dotnet run train InvoiceModel "Invoice extraction model v1"
```

This will:
- Start training on the uploaded documents
- Wait for completion
- Register the model in the local registry with version 1.0
- Store the model ID

### List Registered Models

View all models in the local registry:

```powershell
dotnet run list-models
```

Output example:
```
=== Registered Models ===

Model: InvoiceModel
  Current Model ID: abc123...
  Created: 2024-01-15 10:30:00 UTC
  Updated: 2024-01-15 10:30:00 UTC
  Versions:
    - v1.0 (ACTIVE)
      Model ID: abc123...
      Description: Invoice extraction model v1
      Created: 2024-01-15 10:30:00 UTC
```

### Get Model ID

Retrieve a specific model ID:

```powershell
# Get current active version
dotnet run get-model InvoiceModel

# Get specific version
dotnet run get-model InvoiceModel 1.0
```

### Train Additional Versions

Train a new version of an existing model:

```powershell
# Upload new/updated training documents first
dotnet run upload C:\path\to\updated-training-docs

# Train new version
dotnet run train InvoiceModel "Invoice model v2 with improved accuracy"
```

This automatically creates version 2.0 and sets it as active.

### Set Active Version

Switch between model versions:

```powershell
dotnet run set-active InvoiceModel 1.0
```

### Copy Model to Different Resource

Migrate a model to the target Document Intelligence resource:

```powershell
# Copy current active version
dotnet run copy-model InvoiceModel

# Copy specific version
dotnet run copy-model InvoiceModel 1.0
```

The copied model is registered with name `{ModelName}-copied`.

### Analyze Documents

Use a trained model to analyze documents:

```powershell
dotnet run analyze InvoiceModel C:\path\to\test-invoice.pdf
```

Output includes:
- Model ID used
- Number of pages, tables, and key-value pairs extracted
- Detected document types and confidence scores
- Extracted fields (first 10 shown)

### List Remote Models

View all models in the Azure Document Intelligence resource:

```powershell
dotnet run list-remote
```

## Model Registry

The demo maintains a local `model-registry.json` file that tracks:
- Model names (friendly identifiers)
- Model IDs (Azure-generated GUIDs)
- Versions and descriptions
- Creation and update timestamps
- Currently active version

Example `model-registry.json`:
```json
{
  "InvoiceModel": {
    "ModelName": "InvoiceModel",
    "CurrentModelId": "abc123...",
    "CreatedAt": "2024-01-15T10:30:00Z",
    "UpdatedAt": "2024-01-15T14:20:00Z",
    "Versions": [
      {
        "Version": "1.0",
        "ModelId": "abc123...",
        "Description": "Invoice extraction model v1",
        "CreatedAt": "2024-01-15T10:30:00Z"
      },
      {
        "Version": "2.0",
        "ModelId": "def456...",
        "Description": "Invoice model v2 with improved accuracy",
        "CreatedAt": "2024-01-15T14:20:00Z"
      }
    ]
  }
}
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│          C# Demo Application                    │
│  ┌───────────────────────────────────────────┐  │
│  │         ModelRegistry.cs                  │  │
│  │  - RegisterModel()                        │  │
│  │  - GetModelId()                           │  │
│  │  - SetActiveVersion()                     │  │
│  │  - ListModels()                           │  │
│  └───────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────┐  │
│  │         Program.cs                        │  │
│  │  - Upload documents                       │  │
│  │  - Train models                           │  │
│  │  - Copy models between resources          │  │
│  │  - Analyze documents                      │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
                      │
                      │ Azure SDK
                      │
        ┌─────────────┴─────────────┐
        │                           │
        ▼                           ▼
┌──────────────────┐      ┌──────────────────┐
│  Source Doc AI   │      │  Target Doc AI   │
│    Resource      │──────│    Resource      │
│                  │ Copy │                  │
└──────────────────┘      └──────────────────┘
        │
        │ Training data
        │
        ▼
┌──────────────────┐
│  Azure Blob      │
│  Storage         │
└──────────────────┘
```

## Key Features Demonstrated

1. **Model Training**: Train custom models using Azure Document Intelligence
2. **Version Management**: Track multiple versions of the same model
3. **Model ID Storage**: Maintain a registry of model IDs with friendly names
4. **Version Switching**: Set active model versions
5. **Model Migration**: Copy models between Document Intelligence resources
6. **Document Analysis**: Use trained models to extract data from documents

## Cleanup

To remove all Azure resources created by the demo:

```powershell
.\azure-teardown.ps1
```

Add `-Force` to skip confirmation:
```powershell
.\azure-teardown.ps1 -Force
```

This deletes:
- All Document Intelligence resources
- Storage account and containers
- Resource group
- Local configuration files

## Troubleshooting

### Authentication Issues

**Error: "This request is not authorized to perform this operation" (403)**

This typically means either:
1. You need to log in to Azure CLI: `az login`
2. Network access is blocked - run the setup script again which will fix network settings

**Check your authentication:**
```powershell
az login
az account show

# Verify you have the correct roles
$userId = az ad signed-in-user show --query id --output tsv
az role assignment list --assignee $userId --scope "/subscriptions/YOUR_SUB_ID/resourceGroups/rg-docintel-demo/providers/Microsoft.Storage/storageAccounts/YOUR_STORAGE_ACCOUNT" --query "[].roleDefinitionName" --output tsv
```

You should see "Storage Blob Data Contributor" in the role list.

### Training Fails with "TrainingContentMissing"

This means Document Intelligence can't access the training files. Common causes:

1. **Wrong file format**: Use PDF, JPEG, PNG, TIFF, or BMP files (not .txt)
2. **Not enough documents**: Upload at least 5 different documents
3. **Duplicate files**: Each document should be unique (not copies)
4. **Network restrictions**: Ensure public network access is enabled on storage

**Verify files are uploaded:**
```powershell
cd DocIntelDemo
dotnet run train ModelName "Description"
# The output will show which files are in the container and if they're supported
```

### Policy Restrictions

If you see messages about "allowSharedKeyAccess: false" or policy blocks, don't worry! This demo works with Azure AD authentication, which is the recommended approach. Shared key access is not required.

### Copy Model Fails

- Verify both source and target resources are in the same Azure region
- Ensure target resource has sufficient quota

### Configuration Not Found

- Ensure `appsettings.json` exists in the root directory
- Run `.\azure-setup.ps1` to regenerate configuration

## Additional Resources

- [Azure Document Intelligence Documentation](https://learn.microsoft.com/azure/ai-services/document-intelligence/)
- [Custom Model Training](https://learn.microsoft.com/azure/ai-services/document-intelligence/how-to-guides/build-a-custom-model)
- [Model Copy Operations](https://learn.microsoft.com/azure/ai-services/document-intelligence/how-to-guides/copy-models-across-resource)

## Cost Considerations

- Document Intelligence: Charged per page analyzed and model training hours
- Storage: Minimal cost for blob storage
- Use teardown script to avoid ongoing charges when demo is complete

## License

This demo is provided as-is for demonstration purposes.
