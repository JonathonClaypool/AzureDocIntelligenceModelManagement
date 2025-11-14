# Getting Started - 3 Simple Steps

New to this demo? Start here!

## Step 1: Setup (3 minutes)

```powershell
# Login to Azure
az login

# Run setup
.\azure-setup.ps1
```

## Step 2: Train a Model (2 minutes)

```powershell
cd DocIntelDemo

# Upload sample documents
dotnet run upload ..\SampleTrainingData

# Train model
dotnet run train MyModel "Version 1.0"
```

## Step 3: Use Your Model

```powershell
# List models
dotnet run list-models

# Analyze a document
dotnet run analyze MyModel path\to\document.pdf

# Train new version
dotnet run train MyModel "Version 2.0"
```

## That's It!

✅ You now have a working Document Intelligence demo

📖 **Want more details?** See [QUICKSTART.md](QUICKSTART.md)  
📚 **Full documentation?** See [README.md](README.md)

## Cleanup When Done

```powershell
cd ..
.\azure-teardown.ps1 -Force
```

---

**Quick Tip**: This demo uses Azure AD authentication. Just make sure you run `az login` before starting, and everything will work!
