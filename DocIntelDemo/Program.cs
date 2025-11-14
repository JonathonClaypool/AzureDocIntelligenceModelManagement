using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Azure;
using Azure.AI.FormRecognizer.DocumentAnalysis;
using Azure.Identity;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Microsoft.Extensions.Configuration;

namespace DocIntelDemo
{
    class Program
    {
        private static IConfiguration _configuration;
        private static ModelRegistry _registry;
        private static DocumentModelAdministrationClient _sourceAdminClient;
        private static DocumentModelAdministrationClient _targetAdminClient;

        static async Task Main(string[] args)
        {
            Console.WriteLine("=== Azure Document Intelligence Demo ===\n");

            LoadConfiguration();
            InitializeClients();
            _registry = new ModelRegistry();

            if (args.Length == 0)
            {
                ShowMenu();
                return;
            }

            await ProcessCommand(args);
        }

        static void LoadConfiguration()
        {
            var builder = new ConfigurationBuilder()
                .SetBasePath(
                    Directory
                        .GetParent(AppContext.BaseDirectory)
                        .Parent.Parent.Parent.Parent.FullName
                )
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);

            _configuration = builder.Build();
        }

        static void InitializeClients()
        {
            var sourceEndpoint = _configuration["DocumentIntelligence:Source:Endpoint"];
            var sourceKey = _configuration["DocumentIntelligence:Source:Key"];
            var targetEndpoint = _configuration["DocumentIntelligence:Target:Endpoint"];
            var targetKey = _configuration["DocumentIntelligence:Target:Key"];

            _sourceAdminClient = new DocumentModelAdministrationClient(
                new Uri(sourceEndpoint),
                new AzureKeyCredential(sourceKey)
            );

            _targetAdminClient = new DocumentModelAdministrationClient(
                new Uri(targetEndpoint),
                new AzureKeyCredential(targetKey)
            );

            Console.WriteLine("✓ Document Intelligence clients initialized\n");
        }

        static void ShowMenu()
        {
            Console.WriteLine("Available commands:");
            Console.WriteLine(
                "  dotnet run upload <local-folder-path>           - Upload training documents to storage"
            );
            Console.WriteLine(
                "  dotnet run train <model-name> [description]     - Train a new custom model"
            );
            Console.WriteLine(
                "  dotnet run list-models                          - List all registered models"
            );
            Console.WriteLine("  dotnet run get-model <model-name> [version]     - Get model ID");
            Console.WriteLine(
                "  dotnet run set-active <model-name> <version>    - Set active version"
            );
            Console.WriteLine(
                "  dotnet run copy-model <model-name> [version]    - Copy model to target resource"
            );
            Console.WriteLine(
                "  dotnet run analyze <model-name> <file-path>     - Analyze document with model"
            );
            Console.WriteLine(
                "  dotnet run list-remote                          - List models in source resource"
            );
            Console.WriteLine();
        }

        static async Task ProcessCommand(string[] args)
        {
            try
            {
                var command = args[0].ToLower();

                switch (command)
                {
                    case "upload":
                        if (args.Length < 2)
                        {
                            Console.WriteLine("Usage: dotnet run upload <local-folder-path> [--pdf-only]");
                            return;
                        }
                        var pdfOnly = args.Length > 2 && args[2] == "--pdf-only";
                        await UploadTrainingDocuments(args[1], pdfOnly);
                        break;

                    case "clean-container":
                        await CleanContainer();
                        break;

                    case "train":
                        if (args.Length < 2)
                        {
                            Console.WriteLine("Usage: dotnet run train <model-name> [description]");
                            return;
                        }
                        var description = args.Length > 2 ? string.Join(" ", args.Skip(2)) : "";
                        await TrainModel(args[1], description);
                        break;

                    case "list-models":
                        _registry.ListModels();
                        break;

                    case "get-model":
                        if (args.Length < 2)
                        {
                            Console.WriteLine("Usage: dotnet run get-model <model-name> [version]");
                            return;
                        }
                        var version = args.Length > 2 ? args[2] : null;
                        var modelId = _registry.GetModelId(args[1], version);
                        Console.WriteLine($"Model ID: {modelId}");
                        break;

                    case "set-active":
                        if (args.Length < 3)
                        {
                            Console.WriteLine(
                                "Usage: dotnet run set-active <model-name> <version>"
                            );
                            return;
                        }
                        _registry.SetActiveVersion(args[1], args[2]);
                        break;

                    case "copy-model":
                        if (args.Length < 2)
                        {
                            Console.WriteLine(
                                "Usage: dotnet run copy-model <model-name> [version]"
                            );
                            return;
                        }
                        var copyVersion = args.Length > 2 ? args[2] : null;
                        await CopyModelToTarget(args[1], copyVersion);
                        break;

                    case "analyze":
                        if (args.Length < 3)
                        {
                            Console.WriteLine("Usage: dotnet run analyze <model-name> <file-path>");
                            return;
                        }
                        await AnalyzeDocument(args[1], args[2]);
                        break;

                    case "list-remote":
                        await ListRemoteModels();
                        break;

                    default:
                        Console.WriteLine($"Unknown command: {command}");
                        ShowMenu();
                        break;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

        static async Task UploadTrainingDocuments(string localFolderPath, bool pdfOnly = false)
        {
            if (!Directory.Exists(localFolderPath))
            {
                Console.WriteLine($"Error: Directory '{localFolderPath}' not found");
                return;
            }

            var accountName = _configuration["Storage:AccountName"];
            var containerName = _configuration["Storage:ContainerName"];
            var connectionString = _configuration["Storage:ConnectionString"];

            BlobServiceClient blobServiceClient;
            
            // Use connection string if available, otherwise fall back to Azure AD
            if (!string.IsNullOrEmpty(connectionString) && !connectionString.Contains("YOUR-"))
            {
                Console.WriteLine("Using connection string authentication");
                blobServiceClient = new BlobServiceClient(connectionString);
            }
            else
            {
                Console.WriteLine("Using Azure AD authentication");
                blobServiceClient = new BlobServiceClient(
                    new Uri($"https://{accountName}.blob.core.windows.net"),
                    new DefaultAzureCredential()
                );
            }

            var containerClient = blobServiceClient.GetBlobContainerClient(containerName);

            var files = Directory.GetFiles(localFolderPath);
            
            // Filter files if pdf-only flag is set
            if (pdfOnly)
            {
                var supportedExtensions = new[] { ".pdf", ".jpg", ".jpeg", ".png", ".tiff", ".tif", ".bmp" };
                files = files.Where(f => supportedExtensions.Contains(Path.GetExtension(f).ToLower())).ToArray();
                Console.WriteLine($"Filtering to supported file types only...");
            }
            
            Console.WriteLine($"Uploading {files.Length} files to blob storage...\n");

            foreach (var filePath in files)
            {
                var fileName = Path.GetFileName(filePath);
                var blobClient = containerClient.GetBlobClient(fileName);

                Console.Write($"Uploading {fileName}... ");
                await blobClient.UploadAsync(filePath, overwrite: true);
                Console.WriteLine("✓");
            }

            Console.WriteLine(
                $"\n✓ Successfully uploaded {files.Length} files to container '{containerName}'"
            );

            var sasUri = await GenerateSasUriAsync(blobServiceClient, containerClient);
            Console.WriteLine($"\nContainer SAS URI generated (valid for 24 hours)");
            Console.WriteLine("Use this for training (stored in config for convenience)");
        }

        static async Task CleanContainer()
        {
            Console.WriteLine("Cleaning storage container...\n");

            var accountName = _configuration["Storage:AccountName"];
            var containerName = _configuration["Storage:ContainerName"];
            var connectionString = _configuration["Storage:ConnectionString"];

            BlobServiceClient blobServiceClient;
            
            // Use connection string if available, otherwise fall back to Azure AD
            if (!string.IsNullOrEmpty(connectionString) && !connectionString.Contains("YOUR-"))
            {
                Console.WriteLine("Using connection string authentication");
                blobServiceClient = new BlobServiceClient(connectionString);
            }
            else
            {
                Console.WriteLine("Using Azure AD authentication");
                blobServiceClient = new BlobServiceClient(
                    new Uri($"https://{accountName}.blob.core.windows.net"),
                    new DefaultAzureCredential()
                );
            }

            var containerClient = blobServiceClient.GetBlobContainerClient(containerName);

            int deleteCount = 0;
            await foreach (var blob in containerClient.GetBlobsAsync())
            {
                Console.Write($"Deleting {blob.Name}... ");
                await containerClient.DeleteBlobAsync(blob.Name);
                Console.WriteLine("✓");
                deleteCount++;
            }

            if (deleteCount == 0)
            {
                Console.WriteLine("Container is already empty.");
            }
            else
            {
                Console.WriteLine($"\n✓ Deleted {deleteCount} files from container '{containerName}'");
            }
        }

        static async Task<string> GenerateSasUriAsync(BlobServiceClient blobServiceClient, BlobContainerClient containerClient)
        {
            try
            {
                var sasBuilder = new Azure.Storage.Sas.BlobSasBuilder
                {
                    BlobContainerName = containerClient.Name,
                    Resource = "c",
                    StartsOn = DateTimeOffset.UtcNow.AddMinutes(-5),
                    ExpiresOn = DateTimeOffset.UtcNow.AddHours(24),
                };

                // Document Intelligence needs read, list, and write permissions
                sasBuilder.SetPermissions(
                    Azure.Storage.Sas.BlobContainerSasPermissions.Read
                        | Azure.Storage.Sas.BlobContainerSasPermissions.List
                        | Azure.Storage.Sas.BlobContainerSasPermissions.Write
                );

                // Try to generate SAS with account key if using connection string
                try
                {
                    var sasUri = containerClient.GenerateSasUri(sasBuilder);
                    Console.WriteLine($"Generated SAS URI with account key (expires: {sasBuilder.ExpiresOn:yyyy-MM-dd HH:mm:ss} UTC)");
                    return sasUri.ToString();
                }
                catch
                {
                    // Fall back to user delegation SAS for Azure AD auth
                    var userDelegationKey = await blobServiceClient.GetUserDelegationKeyAsync(
                        startsOn: DateTimeOffset.UtcNow.AddMinutes(-5),
                        expiresOn: DateTimeOffset.UtcNow.AddHours(24)
                    );

                    var sasQueryParams = sasBuilder.ToSasQueryParameters(
                        userDelegationKey.Value,
                        blobServiceClient.AccountName
                    );
                    
                    var uriBuilder = new UriBuilder(containerClient.Uri)
                    {
                        Query = sasQueryParams.ToString()
                    };
                    
                    Console.WriteLine($"Generated SAS URI with user delegation (expires: {sasBuilder.ExpiresOn:yyyy-MM-dd HH:mm:ss} UTC)");
                    return uriBuilder.Uri.ToString();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error generating SAS URI: {ex.Message}");
                throw new Exception("Failed to generate SAS URI for training.", ex);
            }
        }

        static async Task TrainModel(string modelName, string description)
        {
            Console.WriteLine($"Training model '{modelName}'...\n");

            var accountName = _configuration["Storage:AccountName"];
            var containerName = _configuration["Storage:ContainerName"];
            var connectionString = _configuration["Storage:ConnectionString"];

            BlobServiceClient blobServiceClient;
            
            // Use connection string if available, otherwise fall back to Azure AD
            if (!string.IsNullOrEmpty(connectionString) && !connectionString.Contains("YOUR-"))
            {
                Console.WriteLine("Using connection string authentication");
                blobServiceClient = new BlobServiceClient(connectionString);
            }
            else
            {
                Console.WriteLine("Using Azure AD authentication");
                blobServiceClient = new BlobServiceClient(
                    new Uri($"https://{accountName}.blob.core.windows.net"),
                    new DefaultAzureCredential()
                );
            }

            var containerClient = blobServiceClient.GetBlobContainerClient(containerName);

            var trainingFilesUri = new Uri(await GenerateSasUriAsync(blobServiceClient, containerClient));
            
            Console.WriteLine($"Training with container: {containerClient.Name}");
            Console.WriteLine($"Container URI: {containerClient.Uri}");
            Console.WriteLine($"Training URI (with SAS): {trainingFilesUri}");
            Console.WriteLine($"Number of files in container: checking...");
            
            // Verify files exist and list them
            int fileCount = 0;
            Console.WriteLine("\nFiles in container:");
            await foreach (var blob in containerClient.GetBlobsAsync())
            {
                fileCount++;
                var extension = Path.GetExtension(blob.Name).ToLower();
                var supportedExtensions = new[] { ".pdf", ".jpg", ".jpeg", ".png", ".tiff", ".tif", ".bmp" };
                var isSupported = supportedExtensions.Contains(extension);
                var marker = isSupported ? "✓" : "✗";
                Console.WriteLine($"  {marker} {blob.Name} ({extension})");
            }
            Console.WriteLine($"\nTotal files: {fileCount}");
            
            if (fileCount == 0)
            {
                Console.WriteLine("ERROR: No files found in container. Please upload training documents first.");
                return;
            }
            
            Console.WriteLine("\nNOTE: Document Intelligence requires PDF, JPEG, PNG, TIFF, or BMP files.");
            Console.WriteLine("Text files (.txt) are not supported for training.\n");
            
            // Test the SAS URI by trying to list files with it
            Console.WriteLine("Testing SAS URI permissions...");
            try
            {
                var testClient = new BlobContainerClient(trainingFilesUri);
                int testCount = 0;
                await foreach (var blob in testClient.GetBlobsAsync())
                {
                    testCount++;
                    if (testCount <= 3)
                    {
                        Console.WriteLine($"  Can access: {blob.Name}");
                    }
                }
                Console.WriteLine($"✓ SAS URI is valid - can list {testCount} files\n");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"✗ SAS URI test failed: {ex.Message}");
                Console.WriteLine("This means Document Intelligence won't be able to access the files.\n");
                return;
            }

            Console.WriteLine("Attempting to train with SAS token...");
            Console.WriteLine($"URI being sent to Document Intelligence: {trainingFilesUri}\n");

            Console.WriteLine("Starting training operation...");
            var operation = await _sourceAdminClient.BuildDocumentModelAsync(
                WaitUntil.Completed,
                trainingFilesUri,
                DocumentBuildMode.Template
            );

            var model = operation.Value;
            Console.WriteLine($"\n✓ Model training completed!");
            Console.WriteLine($"  Model ID: {model.ModelId}");
            Console.WriteLine($"  Created: {model.CreatedOn}");

            _registry.RegisterModel(modelName, model.ModelId, description: description);
        }

        static async Task CopyModelToTarget(string modelName, string version)
        {
            var modelId = _registry.GetModelId(modelName, version);
            Console.WriteLine(
                $"Copying model '{modelName}' (ID: {modelId}) to target resource...\n"
            );

            var targetResourceId = await _targetAdminClient.GetCopyAuthorizationAsync();

            Console.WriteLine("Initiating copy operation...");
            var operation = await _sourceAdminClient.CopyDocumentModelToAsync(
                WaitUntil.Completed,
                modelId,
                targetResourceId
            );

            var copiedModel = operation.Value;
            Console.WriteLine($"\n✓ Model successfully copied to target resource!");
            Console.WriteLine($"  New Model ID: {copiedModel.ModelId}");
            Console.WriteLine(
                $"  Target Endpoint: {_configuration["DocumentIntelligence:Target:Endpoint"]}"
            );

            var targetModelName = $"{modelName}-copied";
            _registry.RegisterModel(
                targetModelName,
                copiedModel.ModelId,
                description: $"Copied from {modelName}"
            );
        }

        static async Task AnalyzeDocument(string modelName, string filePath)
        {
            if (!File.Exists(filePath))
            {
                Console.WriteLine($"Error: File '{filePath}' not found");
                return;
            }

            var modelId = _registry.GetModelId(modelName);
            Console.WriteLine($"Analyzing document with model '{modelName}' (ID: {modelId})...\n");

            var sourceEndpoint = _configuration["DocumentIntelligence:Source:Endpoint"];
            var sourceKey = _configuration["DocumentIntelligence:Source:Key"];

            var client = new DocumentAnalysisClient(
                new Uri(sourceEndpoint),
                new AzureKeyCredential(sourceKey)
            );

            using var stream = File.OpenRead(filePath);
            var operation = await client.AnalyzeDocumentAsync(WaitUntil.Completed, modelId, stream);
            var result = operation.Value;

            Console.WriteLine($"✓ Analysis completed!\n");
            Console.WriteLine($"Model ID used: {result.ModelId}");
            Console.WriteLine($"Pages: {result.Pages.Count}");
            Console.WriteLine($"Tables: {result.Tables.Count}");
            Console.WriteLine($"Key-Value Pairs: {result.KeyValuePairs.Count}");

            if (result.Documents.Count > 0)
            {
                Console.WriteLine($"\nExtracted Documents: {result.Documents.Count}");
                foreach (var document in result.Documents)
                {
                    Console.WriteLine(
                        $"\n  Document Type: {document.DocumentType} (Confidence: {document.Confidence:P})"
                    );
                    Console.WriteLine($"  Fields: {document.Fields.Count}");

                    foreach (var field in document.Fields.Take(10))
                    {
                        Console.WriteLine($"    - {field.Key}: {field.Value.Content}");
                    }

                    if (document.Fields.Count > 10)
                    {
                        Console.WriteLine($"    ... and {document.Fields.Count - 10} more fields");
                    }
                }
            }
        }

        static async Task ListRemoteModels()
        {
            Console.WriteLine("=== Models in Source Resource ===\n");

            var models = _sourceAdminClient.GetDocumentModelsAsync();

            await foreach (var model in models)
            {
                Console.WriteLine($"Model ID: {model.ModelId}");
                Console.WriteLine($"  Description: {model.Description ?? "(none)"}");
                Console.WriteLine($"  Created: {model.CreatedOn}");
                if (model.ExpiresOn.HasValue)
                {
                    Console.WriteLine($"  Expires: {model.ExpiresOn.Value}");
                }
                Console.WriteLine();
            }
        }
    }
}
