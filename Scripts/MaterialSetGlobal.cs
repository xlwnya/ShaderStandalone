using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;
using YamlDotNet.Serialization;

namespace Xlwnya.ShaderStandalone.Scripts
{
    public class MaterialSetGlobal: MonoBehaviour
    {
        public bool applyKeywords = true;
        public string shaderRegexpPattern;
        public string standaloneShaderPrefix = "Standalone/";
        public string outputPrefix = "Standalone/";
        public string yamlPath;
        public Material[] origMaterial;
        public Material[] replacedMaterial;
    }

    #if UNITY_EDITOR
    [CustomEditor(typeof(MaterialSetGlobal))]
    public class MaterialSetGlobalEditor : Editor
    {
        private const string ReplaceCacheName = "materialReplaceCache.asset";
        SerializedProperty _yamlPath;
        
        private void OnEnable()
        {
            _yamlPath = serializedObject.FindProperty("yamlPath");
        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();
            DrawDefaultInspector();
            bool execSelectYamlPath = GUILayout.Button("SelectYamlPath");
            bool execSetGlobal = GUILayout.Button("SetGlobal");
            bool execRevertMaterial = GUILayout.Button("RevertMaterial");
            
            if (execSelectYamlPath) SelectYamlPath();
            
            serializedObject.ApplyModifiedProperties();

            if (execSetGlobal) SetGlobal();
            if (execRevertMaterial) RevertMaterial();
            if (execSetGlobal || execRevertMaterial) serializedObject.Update();
        }

        private void SelectYamlPath()
        {
            string selected = EditorUtility.OpenFilePanel("Select yaml file.", "Assets/", "yml");
            if (selected.Length > 0)
            {
                Regex dataPathRegex = new Regex(Application.dataPath);
                selected = dataPathRegex.Replace(selected, "Assets", 1);
                _yamlPath.stringValue = selected;
            }
        }

        private void RevertMaterial()
        {
            MaterialSetGlobal self = (MaterialSetGlobal) target;
            var reverseReplaceCache = buildReplaceCache(self.replacedMaterial, self.origMaterial);

            foreach (var terrain in FindObjectsOfType<Terrain>())
            {
                Material mat = terrain.materialTemplate;
                if (reverseReplaceCache.ContainsKey(mat))
                {
                    terrain.materialTemplate = reverseReplaceCache[mat];
                }
            }

            foreach (var renderer in FindObjectsOfType<MeshRenderer>())
            {
                bool matChanged = false;
                var mats = renderer.sharedMaterials;
                for (int matIndex = 0; matIndex < mats.Length; matIndex++)
                {
                    var mat = mats[matIndex];
                    if (reverseReplaceCache.ContainsKey(mat))
                    {
                        mats[matIndex] = reverseReplaceCache[mat];
                        matChanged = true;
                    }
                }

                if (matChanged)
                {
                    renderer.sharedMaterials = mats;
                }
            }
        }

        private void SetGlobal()
        {
            MaterialSetGlobal self = (MaterialSetGlobal) target;
            var replaceCache = buildReplaceCache(self.origMaterial, self.replacedMaterial);

            Regex shaderRegex = new Regex(self.shaderRegexpPattern, RegexOptions.Compiled);
            var standaloneShaderPrefix = self.standaloneShaderPrefix;
            var outputPrefix = self.outputPrefix;

            var deserializer = new DeserializerBuilder().Build();
            var loaded =
                deserializer.Deserialize<Dictionary<string, Dictionary<string, string>[]>>(
                    File.ReadAllText(self.yamlPath));

            foreach (var terrain in FindObjectsOfType<Terrain>())
            {
                Material mat = terrain.materialTemplate;
                // 既に置換済の場合
                if (replaceCache.ContainsValue(mat)) continue;
                if (replaceCache.ContainsKey(mat))
                {
                    terrain.materialTemplate = replaceCache[mat];
                    continue;
                }
                
                if (mat is null) continue;
                Shader shader = mat.shader;
                if (shader is null) continue;
                if (shaderRegex.IsMatch(shader.name))
                {
                    var objPath = ObjectPath(terrain.gameObject);
                    Material newMat = MatSetGlobal(mat, shader, standaloneShaderPrefix, objPath, outputPrefix, self.applyKeywords, loaded);
                    terrain.materialTemplate = newMat;
                    replaceCache.Add(mat, newMat);
                }
            }

            foreach (var renderer in FindObjectsOfType<MeshRenderer>())
            {
                bool matChanged = false;
                var mats = renderer.sharedMaterials;
                for (int matIndex = 0; matIndex < mats.Length; matIndex++)
                {
                    Material mat = mats[matIndex];
                    if (mat is null) continue;
                    // 既に置換済の場合
                    if (replaceCache.ContainsValue(mat)) continue;
                    if (replaceCache.ContainsKey(mat))
                    {
                        mats[matIndex] = replaceCache[mat];
                        matChanged = true;
                        continue;
                    }
                
                    Shader shader = mat.shader;
                    if (shader is null) continue;
                    if (shaderRegex.IsMatch(shader.name))
                    {
                        var objPath = ObjectPath(renderer.gameObject);
                    
                        Material newMat =
                            MatSetGlobal(mat, shader, standaloneShaderPrefix, objPath, outputPrefix, self.applyKeywords, loaded);
                    
                        mats[matIndex] = newMat;
                        matChanged = true;
                        replaceCache.Add(mat, newMat);
                    }
                }
                if (matChanged)
                {
                    renderer.sharedMaterials = mats;
                }
            }

            applyReplaceCache(self, replaceCache);
        }

        private Material MatSetGlobal(
            Material mat,
            Shader shader,
            string standaloneShaderPrefix,
            string objPath,
            string outputPrefix,
            bool applyKeywords,
            Dictionary<string, Dictionary<string, string>[]> loaded)
        {
            string replacementShaderName = $"{standaloneShaderPrefix}{shader.name}";
            var replacementShader = Shader.Find(replacementShaderName);
            if (replacementShader is null)
            {
                Debug.LogWarning($"replacementShader not found.:{replacementShaderName}");
                return mat;
            }

            Material newMat = new Material(mat);
            newMat.shader = replacementShader;

            foreach (var prop in loaded["inuseGlobalProps"])
            {
                var propName = prop["name"];
                var type = prop["methodType"];
                copyValueIfExist(propName, type, newMat, mat, true);
            }

            if (applyKeywords)
            {
                foreach (var keyword in loaded["keywords"])
                {
                    var keywordName = keyword["name"];
                    if (Shader.IsKeywordEnabled(keywordName))
                    {
                        newMat.EnableKeyword(keywordName);
                    }

                    if (mat.IsKeywordEnabled(keywordName))
                    {
                        newMat.EnableKeyword(keywordName);
                    }
                }
            }

            string matPath = AssetDatabase.GenerateUniqueAssetPath($"Assets/{outputPrefix}{objPath}.mat");
            AssetDatabase.CreateAsset(newMat, matPath);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            return newMat;
        }
                
        private bool isColorZero(Color c)
        {
            return new Vector4(c.r, c.g, c.b, c.a).magnitude == 0;
        }

        private Dictionary<Material, Material> buildReplaceCache(Material[] origMaterial, Material[] replacedMaterial)
        {
            var replaceCache = new Dictionary<Material, Material>();
            var minimumLength = Math.Max(origMaterial.Length, replacedMaterial.Length);
            for (int i = 0; i < minimumLength; i++)
            {
                replaceCache.Add(origMaterial[i], replacedMaterial[i]);
            }

            return replaceCache;
        }

        private void applyReplaceCache(MaterialSetGlobal self, Dictionary<Material, Material> replaceCache)
        {
            var origMaterial = new List<Material>();
            var replacedMaterial = new List<Material>();
            foreach (var elem in replaceCache)
            {
                origMaterial.Add(elem.Key);
                replacedMaterial.Add(elem.Value);
            }

            self.origMaterial = origMaterial.ToArray();
            self.replacedMaterial = replacedMaterial.ToArray();
            EditorUtility.SetDirty(self);
        }

        private string ObjectPath(GameObject obj)
        {
            var objectPath = new List<string>();
            Transform objTrans = obj.transform;
            objectPath.Add(obj.name);
            while (null != (objTrans = objTrans.parent))
            {
                objectPath.Add(objTrans.gameObject.name);
            }

            objectPath.Reverse();
            var builder = new StringBuilder();
            foreach (var name in objectPath)
            {
                builder.Append(name);
                builder.Append("_");
            }

            builder.Append("material");

            return builder.ToString();
        }

        private void copyValueIfExist(string propName, string propType, Material to, Material from, bool fromGlobal)
        {
            switch (propType) 
            {
                case "Texture":
                    if (fromGlobal && !(Shader.GetGlobalTexture(propName) is null))
                    {
                        to.SetTexture(propName, Shader.GetGlobalTexture(propName));
                    }

                    if (from is null) break;
                    if (from.HasProperty(propName) && !(from.GetTexture(propName) is null))
                    {
                        to.SetTexture(propName, from.GetTexture(propName));
                    }
                    break;
                case "Float":
                    if (fromGlobal && Shader.GetGlobalFloat(propName) != 0)
                    {
                        to.SetFloat(propName, Shader.GetGlobalFloat(propName));
                    }

                    if (from is null) break;
                    if (from.HasProperty(propName) && from.GetFloat(propName) != 0)
                    {
                        to.SetFloat(propName, from.GetFloat(propName));
                    }
                    break;
                case "Int":
                    if (fromGlobal && Shader.GetGlobalInt(propName) != 0)
                    {
                        to.SetInt(propName, Shader.GetGlobalInt(propName));
                    }

                    if (from is null) break;
                    if (from.HasProperty(propName) && from.GetInt(propName) != 0)
                    {
                        to.SetInt(propName, from.GetInt(propName));
                    }
                    break;
                case "Vector":
                    if (fromGlobal)
                    {
                        if (Shader.GetGlobalVector(propName).magnitude != 0)
                        {
                            to.SetVector(propName, Shader.GetGlobalVector(propName));
                        } else if (!isColorZero(Shader.GetGlobalColor(propName)))
                        {
                            to.SetColor(propName, Shader.GetGlobalColor(propName));
                        }
                    }
 
                    if (from is null || !from.HasProperty(propName)) break;
                    if (from.GetVector(propName).magnitude != 0)
                    {
                        to.SetVector(propName, from.GetVector(propName));
                    }
                    else if (!isColorZero(from.GetColor(propName)))
                    {
                        to.SetColor(propName, from.GetColor(propName));
                    }
                    break;
                default:
                    Debug.LogError($"unknown type: {propType}");
                    break;
            }
        }
    }
#endif
}
