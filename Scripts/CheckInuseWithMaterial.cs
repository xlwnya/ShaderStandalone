using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;
using YamlDotNet.Serialization;

namespace Xlwnya.ShaderStandalone.Scripts
{
    public class CheckInuseWithMaterial : MonoBehaviour
    {
            public string shaderRegexpPattern;
            public string yamlPath;
    }

    #if UNITY_EDITOR
    [CustomEditor(typeof(CheckInuseWithMaterial))]
    public class CheckInuseWithMaterialEditor : Editor
    {
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
            bool execCheckInuse = GUILayout.Button("checkInuse");
            
            if (execSelectYamlPath) SelectYamlPath();
            
            serializedObject.ApplyModifiedProperties();
            if (execCheckInuse) CheckInuse();
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
        
        private List<Material> FindTargetMaterials(string shaderRegexpPattern)
        {
            Regex shaderRegex = new Regex(shaderRegexpPattern, RegexOptions.Compiled);
            var matSet = new HashSet<Material>();
            foreach (var terrain in FindObjectsOfType<Terrain>())
            {
                var mat = terrain.materialTemplate;
                if (mat is null) continue;
                var shader = mat.shader;
                if (shader is null) continue;
                if (shaderRegex.IsMatch(shader.name))
                {
                    matSet.Add(mat);
                }
            }
            foreach (var renderer in FindObjectsOfType<MeshRenderer>())
            {
                var mat = renderer.sharedMaterial;
                if (mat is null) continue;
                var shader = mat.shader;
                if (shader is null) continue;
                if (shaderRegex.IsMatch(shader.name))
                {
                    matSet.Add(mat);
                }
            }

            return matSet.ToList();
        }

        private bool isColorZero(Color c)
        {
            return new Vector4(c.r, c.g, c.b, c.a).magnitude == 0;
        }
        
        private void CheckInuse()
        {
            CheckInuseWithMaterial self = (CheckInuseWithMaterial) target;
            var matList = FindTargetMaterials(self.shaderRegexpPattern);
            if (self.yamlPath is null || self.yamlPath == "")
            {
                Debug.LogError("yamlPath not set");
                return;
            }
            if (!File.Exists(self.yamlPath))
            {
                Debug.LogError($"yamlPath: {self.yamlPath} not exist.");
                return;
            }

            var inuse = new List<Dictionary<string, string>>();
            var deserializer = new DeserializerBuilder().Build();
            var loaded = deserializer.Deserialize<Dictionary<string, Dictionary<string, string>[]>>(File.ReadAllText(self.yamlPath));
            foreach (var prop in loaded["globalProps"])
            {
                var propName = prop["name"];
                var type = prop["methodType"];
                switch (type)
                {
                    case "Texture":
                        if (!(Shader.GetGlobalTexture(propName) is null))
                        {
                            inuse.Add(prop);
                            break;
                        }
                        foreach (var mat in matList)
                        {
                            if (mat.HasProperty(propName) && !(mat.GetTexture(propName) is null))
                            {
                                inuse.Add(prop);
                                break;
                            }
                        }
                        break;
                    case "Float":
                        if (Shader.GetGlobalFloat(propName) != 0)
                        {
                            inuse.Add(prop);
                            break;
                        }
                        foreach (var mat in matList)
                        {
                            if (mat.HasProperty(propName) && mat.GetFloat(propName) != 0)
                            {
                                inuse.Add(prop);
                                break;
                            }
                        }
                        break;
                    case "Int":
                        if (Shader.GetGlobalInt(propName) != 0)
                        {
                            inuse.Add(prop);
                            break;
                        }
                        foreach (var mat in matList)
                        {
                            if (mat.HasProperty(propName) && mat.GetInt(propName) != 0)
                            {
                                inuse.Add(prop);
                                break;
                            }
                        }
                        break;
                    case "Vector":
                        if (Shader.GetGlobalVector(propName).magnitude != 0 || !isColorZero(Shader.GetGlobalColor(propName)))
                        {
                            inuse.Add(prop);
                            break;
                        }
                        foreach (var mat in matList)
                        {
                            if (mat.HasProperty(propName) && (mat.GetVector(propName).magnitude != 0 || !isColorZero(mat.GetColor(propName))))
                            {
                                inuse.Add(prop);
                                break;
                            }
                        }
                        break;
                    default:
                        Debug.LogError($"unknown type: {type}");
                        break;
                }
            }

            loaded["inuseGlobalProps"] = inuse.ToArray();

            var serializer = new SerializerBuilder().Build();
            File.WriteAllText(self.yamlPath, serializer.Serialize(loaded));
        }
    }
    #endif
}
