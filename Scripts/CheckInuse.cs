using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;
using YamlDotNet.Serialization;

namespace Xlwnya.ShaderStandalone.Scripts
{
    public class CheckInuse : MonoBehaviour
    {
        public string yamlPath;
    }

    #if UNITY_EDITOR
    [CustomEditor(typeof(CheckInuse))]
    public class CheckInuseEditor : Editor
    {
        SerializedProperty _yamlPath;
        
        private void OnEnable()
        {
            _yamlPath = serializedObject.FindProperty("yamlPath");
        }

        public override void OnInspectorGUI()
        {
            CheckInuse self = (CheckInuse) target;
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

        private bool isColorZero(Color c)
        {
            return new Vector4(c.r, c.g, c.b, c.a).magnitude == 0;
        }
        
        private void CheckInuse()
        {
            CheckInuse self = (CheckInuse) target;
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
                        if (!(Shader.GetGlobalTexture(propName) is null)) inuse.Add(prop);
                        break;
                    case "Float":
                        if (Shader.GetGlobalFloat(propName) != 0) inuse.Add(prop);
                        break;
                    case "Int":
                        if (Shader.GetGlobalInt(propName) != 0) inuse.Add(prop);
                        break;
                    case "Vector":
                        if (Shader.GetGlobalVector(propName).magnitude != 0 || !isColorZero(Shader.GetGlobalColor(propName)))
                        {
                            inuse.Add(prop);
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
