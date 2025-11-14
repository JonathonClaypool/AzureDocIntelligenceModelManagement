# Azure Document Intelligence Demo - Project Summary

## Project Structure

```
DocumentIntelligence/
├── azure-setup.ps1              # Creates all Azure resources
├── azure-teardown.ps1           # Cleans up all Azure resources
├── README.md                    # Complete documentation
├── QUICKSTART.md                # Step-by-step demo guide
├── TRAINING_DOCUMENTS.md        # Guide for preparing training docs
├── .gitignore                   # Git ignore patterns
└── DocIntelDemo/                # C# demo application
    ├── DocIntelDemo.csproj      # Project file
    ├── Program.cs               # Main application logic
    └── ModelRegistry.cs         # Model versioning system
```

## What This Demo Does

### 1. Azure Infrastructure Setup
The `azure-setup.ps1` script creates:
- **Resource Group**: Container for all resources
- **Storage Account**: Stores training documents
- **Source Document Intelligence**: Primary AI resource for training
- **Target Document Intelligence**: Secondary resource for migration demo
- **Configuration Files**: `appsettings.json` and `.env` with credentials

### 2. C# Demo Application Features

#### Model Training
- Train custom Document Intelligence models from sample documents
- Automatically generate and store model IDs
- Track training metadata (date, description, etc.)

#### Model Version Management
- Register models with friendly names (e.g., "InvoiceModel")
- Automatically version each training (v1.0, v2.0, etc.)
- Store version history in `model-registry.json`
- Set active version for each model
- Retrieve model IDs by name and version

#### Model Migration
- Copy models between Document Intelligence resources
- Demonstrate promotion workflows (dev → test → prod)
- Maintain registry of copied models

#### Document Analysis
- Use trained models to extract data from documents
- Display extracted fields, tables, and key-value pairs
- Show confidence scores and document types

## Key Features Highlighted for Client

### ✅ Train Custom Models
```powershell
dotnet run train InvoiceModel "My invoice extraction model"
```
Demonstrates how to train a model on custom document types.

### ✅ Store Multiple Model Versions
```json
{
  "InvoiceModel": {
    "CurrentModelId": "def456...",
    "Versions": [
      { "Version": "1.0", "ModelId": "abc123..." },
      { "Version": "2.0", "ModelId": "def456..." }
    ]
  }
}
```
Client can maintain multiple versions for A/B testing or rollback.

### ✅ Retrieve Model IDs
```powershell
# Get current active version
dotnet run get-model InvoiceModel

# Get specific version
dotnet run get-model InvoiceModel 1.0
```
Easy retrieval using friendly names instead of GUIDs.

### ✅ Set Active Version
```powershell
dotnet run set-active InvoiceModel 1.0
```
Switch between versions without retraining.

### ✅ Migrate Models Between Resources
```powershell
dotnet run copy-model InvoiceModel
```
Copy models to different regions or environments.

## Technologies Used

- **Azure Document Intelligence**: AI service for custom form/document extraction
- **Azure Blob Storage**: Storage for training documents
- **Azure CLI**: Infrastructure automation
- **C# / .NET 8.0**: Demo application
- **Azure SDK for .NET**: Document Intelligence client library
- **Newtonsoft.Json**: JSON serialization for registry
- **PowerShell 7**: Setup and teardown automation

## Azure Services Created

| Service | Purpose | SKU |
|---------|---------|-----|
| Resource Group | Container | N/A |
| Storage Account | Training docs storage | Standard_LRS |
| Document Intelligence (Source) | Model training & analysis | S0 |
| Document Intelligence (Target) | Migration destination | S0 |

## Demo Workflow

```
┌─────────────────────────────────────────────────┐
│  1. Run azure-setup.ps1                         │
│     Creates Azure resources + config files      │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│  2. Upload training documents                   │
│     dotnet run upload training-docs/            │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│  3. Train model (v1.0)                          │
│     dotnet run train InvoiceModel "v1"          │
│     → Stores model ID in registry               │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│  4. Get model ID                                │
│     dotnet run get-model InvoiceModel           │
│     → Returns stored model ID                   │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│  5. Train updated model (v2.0)                  │
│     dotnet run train InvoiceModel "v2"          │
│     → Creates new version automatically         │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│  6. Set active version                          │
│     dotnet run set-active InvoiceModel 1.0      │
│     → Switches active version                   │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│  7. Copy to target resource                     │
│     dotnet run copy-model InvoiceModel          │
│     → Migrates model to different resource      │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│  8. Analyze documents                           │
│     dotnet run analyze InvoiceModel doc.pdf     │
│     → Extracts data using active version        │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│  9. Run azure-teardown.ps1                      │
│     Deletes all Azure resources                 │
└─────────────────────────────────────────────────┘
```

## Prerequisites for Client Demo

- Azure subscription with contributor access
- Azure CLI installed
- .NET 8.0 SDK installed
- PowerShell 7.0+ installed
- At least 5 sample documents with similar structure

## Time Estimates

- Setup: 5 minutes
- Document preparation: 5 minutes
- First model training: 2-5 minutes
- Second model training: 2-5 minutes
- Demo walkthrough: 15-20 minutes
- Teardown: 2 minutes

**Total: 30-40 minutes**

## Cost Estimates (per demo run)

- Document Intelligence training: ~$1-2
- Storage: <$0.01
- Document analysis: ~$0.01 per document

**Total: ~$2-3 per complete demo**

💡 **Remember to run teardown script to avoid ongoing charges!**

## Getting Started

1. Review `QUICKSTART.md` for step-by-step instructions
2. Run `.\azure-setup.ps1` to create resources
3. Follow the demo workflow above
4. Run `.\azure-teardown.ps1` when complete

## Support Files

- **README.md**: Comprehensive documentation with architecture diagrams
- **QUICKSTART.md**: Step-by-step demo guide
- **TRAINING_DOCUMENTS.md**: Guide for document preparation
- **.gitignore**: Prevents committing credentials

## Security Notes

- ✅ `.gitignore` excludes `appsettings.json` and `.env`
- ✅ Keys stored locally only, not in source control
- ✅ SAS tokens expire after 24 hours
- ✅ Teardown script removes all resources and local configs

## Next Steps for Client

After the demo, the client can:
1. Modify the code to integrate with their systems
2. Add more sophisticated registry features (database-backed, etc.)
3. Implement CI/CD for model training and deployment
4. Add monitoring and logging
5. Integrate with their document management system
6. Scale to multiple document types and models

## Questions to Discuss with Client

1. What document types do you want to process?
2. How many versions do you need to maintain?
3. Do you need multi-region deployment?
4. What's your approval process for model promotion?
5. How will you integrate this with existing systems?
6. Do you need audit logging for model changes?
7. What's your expected document volume?

---

**Ready to run the demo? Start with `QUICKSTART.md`!**
