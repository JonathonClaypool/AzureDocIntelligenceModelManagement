#Requires -Version 7.0

<#
.SYNOPSIS
    Converts text invoice files to PDF format for Document Intelligence training
.DESCRIPTION
    Creates PDF versions of the sample invoice text files using HTML as an intermediate format
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SourceFolder = "SampleTrainingData",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFolder = "SampleTrainingData\PDFs"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Converting Text Files to PDF ===" -ForegroundColor Cyan
Write-Host ""

# Check if source folder exists
if (-not (Test-Path $SourceFolder)) {
    Write-Host "✗ Source folder not found: $SourceFolder" -ForegroundColor Red
    exit 1
}

# Create output folder
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    Write-Host "✓ Created output folder: $OutputFolder" -ForegroundColor Green
}

# Get all .txt files except README
$txtFiles = Get-ChildItem -Path $SourceFolder -Filter "*.txt" | Where-Object { $_.Name -ne "README.md" -and $_.Name -notlike "README*" }

if ($txtFiles.Count -eq 0) {
    Write-Host "✗ No .txt files found in $SourceFolder" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($txtFiles.Count) text files to convert`n" -ForegroundColor Yellow

# Check for wkhtmltopdf
$wkhtmltopdf = Get-Command wkhtmltopdf -ErrorAction SilentlyContinue

if (-not $wkhtmltopdf) {
    Write-Host "wkhtmltopdf not found. Using built-in method..." -ForegroundColor Yellow
    Write-Host "For better results, install wkhtmltopdf: https://wkhtmltopdf.org/downloads.html`n" -ForegroundColor Gray
}

foreach ($file in $txtFiles) {
    $outputFile = Join-Path $OutputFolder "$($file.BaseName).pdf"
    
    Write-Host "Converting $($file.Name)..." -NoNewline
    
    try {
        # Read the text content
        $content = Get-Content $file.FullName -Raw
        
        # Create HTML with proper formatting
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body {
            font-family: 'Courier New', monospace;
            font-size: 10pt;
            white-space: pre;
            margin: 1in;
            line-height: 1.2;
        }
    </style>
</head>
<body>
$content
</body>
</html>
"@
        
        # Save HTML temporarily
        $tempHtml = [System.IO.Path]::GetTempFileName() + ".html"
        $html | Out-File -FilePath $tempHtml -Encoding UTF8
        
        if ($wkhtmltopdf) {
            # Use wkhtmltopdf if available
            & wkhtmltopdf --quiet --page-size Letter --margin-top 25mm --margin-bottom 25mm `
                --margin-left 25mm --margin-right 25mm $tempHtml $outputFile 2>$null
        } else {
            # Fallback: Use Chrome if available
            $chrome = Get-Command chrome -ErrorAction SilentlyContinue
            if (-not $chrome) {
                $chrome = Get-Command "C:\Program Files\Google\Chrome\Application\chrome.exe" -ErrorAction SilentlyContinue
            }
            
            if ($chrome) {
                & $chrome --headless --disable-gpu --print-to-pdf=$outputFile $tempHtml 2>$null
                Start-Sleep -Milliseconds 500
            } else {
                Write-Host " ✗ (No PDF converter found)" -ForegroundColor Yellow
                Remove-Item $tempHtml -Force
                continue
            }
        }
        
        # Clean up temp HTML
        Remove-Item $tempHtml -Force
        
        if (Test-Path $outputFile) {
            Write-Host " ✓" -ForegroundColor Green
        } else {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
    catch {
        Write-Host " ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
$pdfCount = (Get-ChildItem -Path $OutputFolder -Filter "*.pdf").Count
Write-Host "=== Conversion Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Created $pdfCount PDF files in: $OutputFolder" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Upload PDFs: " -NoNewline
Write-Host "dotnet run upload $OutputFolder" -ForegroundColor Cyan
Write-Host "  2. Train model: " -NoNewline
Write-Host "dotnet run train InvoiceModel 'v1.0'" -ForegroundColor Cyan
Write-Host ""

# Offer to open the folder
if ($pdfCount -gt 0) {
    $response = Read-Host "Open the PDF folder? (y/n)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Invoke-Item $OutputFolder
    }
}
