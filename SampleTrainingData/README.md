# Sample Training Data

This folder contains 5 sample form images that can be used to train a Document Intelligence custom model.

## Contents

- **Form_1.jpg** through **Form_5.jpg**: Sample form images
- **fields.json**: Field schema definition
- **\*.labels.json**: Ground truth labels for each form
- **\*.ocr.json**: OCR results for each form

## Usage

Use these files to quickly test the demo:

```powershell
cd DocIntelDemo
dotnet run upload ..\SampleTrainingData
dotnet run train SampleFormModel "Training on sample forms"
```

## File Format

All images are in JPEG format, which is supported by Azure Document Intelligence. The service also supports:
- PDF
- PNG
- TIFF
- BMP

## Creating Your Own Training Set

To train with your own documents:
1. Collect at least 5 similar documents (invoices, forms, receipts, etc.)
2. Ensure they are in a supported format (PDF or images)
3. Place them in a separate folder
4. Upload and train:
   ```powershell
   dotnet run upload ..\your-training-folder
   dotnet run train YourModel "Description"
   ```
