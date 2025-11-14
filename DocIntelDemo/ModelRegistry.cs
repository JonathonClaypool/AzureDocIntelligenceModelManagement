using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json;

namespace DocIntelDemo
{
    public class ModelRegistry
    {
        private const string RegistryFileName = "model-registry.json";
        private Dictionary<string, ModelInfo> _models;

        public ModelRegistry()
        {
            Load();
        }

        public void RegisterModel(string modelName, string modelId, string version = "1.0", string description = "")
        {
            if (_models.ContainsKey(modelName))
            {
                var existingVersions = _models[modelName].Versions.Count;
                version = $"{existingVersions + 1}.0";
            }

            var modelInfo = new ModelInfo
            {
                ModelName = modelName,
                CurrentModelId = modelId,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            var versionInfo = new ModelVersionInfo
            {
                Version = version,
                ModelId = modelId,
                Description = description,
                CreatedAt = DateTime.UtcNow
            };

            if (_models.ContainsKey(modelName))
            {
                _models[modelName].Versions.Add(versionInfo);
                _models[modelName].CurrentModelId = modelId;
                _models[modelName].UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                modelInfo.Versions.Add(versionInfo);
                _models[modelName] = modelInfo;
            }

            Save();
            Console.WriteLine($"✓ Model '{modelName}' version {version} registered with ID: {modelId}");
        }

        public string GetModelId(string modelName, string version = null)
        {
            if (!_models.ContainsKey(modelName))
            {
                throw new Exception($"Model '{modelName}' not found in registry");
            }

            if (string.IsNullOrEmpty(version))
            {
                return _models[modelName].CurrentModelId;
            }

            var versionInfo = _models[modelName].Versions.Find(v => v.Version == version);
            if (versionInfo == null)
            {
                throw new Exception($"Version {version} not found for model '{modelName}'");
            }

            return versionInfo.ModelId;
        }

        public void SetActiveVersion(string modelName, string version)
        {
            if (!_models.ContainsKey(modelName))
            {
                throw new Exception($"Model '{modelName}' not found in registry");
            }

            var versionInfo = _models[modelName].Versions.Find(v => v.Version == version);
            if (versionInfo == null)
            {
                throw new Exception($"Version {version} not found for model '{modelName}'");
            }

            _models[modelName].CurrentModelId = versionInfo.ModelId;
            _models[modelName].UpdatedAt = DateTime.UtcNow;
            Save();

            Console.WriteLine($"✓ Set active version of '{modelName}' to {version} (Model ID: {versionInfo.ModelId})");
        }

        public void ListModels()
        {
            if (_models.Count == 0)
            {
                Console.WriteLine("No models registered.");
                return;
            }

            Console.WriteLine("\n=== Registered Models ===\n");
            foreach (var kvp in _models)
            {
                var model = kvp.Value;
                Console.WriteLine($"Model: {model.ModelName}");
                Console.WriteLine($"  Current Model ID: {model.CurrentModelId}");
                Console.WriteLine($"  Created: {model.CreatedAt:yyyy-MM-dd HH:mm:ss} UTC");
                Console.WriteLine($"  Updated: {model.UpdatedAt:yyyy-MM-dd HH:mm:ss} UTC");
                Console.WriteLine($"  Versions:");

                foreach (var version in model.Versions)
                {
                    var isActive = version.ModelId == model.CurrentModelId ? " (ACTIVE)" : "";
                    Console.WriteLine($"    - v{version.Version}{isActive}");
                    Console.WriteLine($"      Model ID: {version.ModelId}");
                    if (!string.IsNullOrEmpty(version.Description))
                    {
                        Console.WriteLine($"      Description: {version.Description}");
                    }
                    Console.WriteLine($"      Created: {version.CreatedAt:yyyy-MM-dd HH:mm:ss} UTC");
                }
                Console.WriteLine();
            }
        }

        private void Load()
        {
            if (File.Exists(RegistryFileName))
            {
                var json = File.ReadAllText(RegistryFileName);
                _models = JsonConvert.DeserializeObject<Dictionary<string, ModelInfo>>(json);
            }
            else
            {
                _models = new Dictionary<string, ModelInfo>();
            }
        }

        private void Save()
        {
            var json = JsonConvert.SerializeObject(_models, Formatting.Indented);
            File.WriteAllText(RegistryFileName, json);
        }
    }

    public class ModelInfo
    {
        public string ModelName { get; set; }
        public string CurrentModelId { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public List<ModelVersionInfo> Versions { get; set; } = new List<ModelVersionInfo>();
    }

    public class ModelVersionInfo
    {
        public string Version { get; set; }
        public string ModelId { get; set; }
        public string Description { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
