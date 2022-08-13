#!/usr/bin/env ruby

require 'fileutils'
require 'yaml'
require 'pathname'

if ARGV.size < 5
    STDERR.puts "Usage: #{$0} className shaderinclude.txt shaderprops.txt shaderval.txt shaderkeywords.txt"
    STDERR.puts "className = debug class basename."
    STDERR.puts "  Create global shader values debug class and data files (className.yml & className_forUnity.yml)"
    STDERR.puts "Example: make_debugclass.rb Debug shaderinclude.txt shaderprops.txt shaderval.txt shaderkeywords.txt"
    exit 1
end

className = ARGV.shift
includeFile = ARGV.shift
propsFile = ARGV.shift
valsFile = ARGV.shift
keywordsFile = ARGV.shift

PROPTYPEDEF = {
    "2D" => :Texture,
    "Cube" => :TextureCube,
    "3D" => :Texture3D,
    "Int" => :int,
    "Float" => :float,
    "Range" => :float,
    "Color" => :vector,
    "Vector" => :vector,
}
TYPEDEF = {
    "sampler2D" => { type: :Texture, fieldType: 'Texture', methodType: 'Texture', propgen: ->(name) { "#{name}(\"#{name}\", 2D) = \"\" {}" }, },
    "samplerCUBE" => { type: :TextureCube, fieldType: 'Texture', methodType: 'Texture', propgen: ->(name) { "#{name}(\"#{name}\", Cube) = \"\" {}" }, },
    "sampler3D" => { type: :Texture3D, fieldType: 'Texture', methodType: 'Texture', propgen: ->(name) { "#{name}(\"#{name}\", 3D) = \"\" {}" }, },
    "int" => { type: :int, fieldType: 'int', methodType: 'Int', propgen: ->(name) { "#{name}(\"#{name}\", Int) = 0" }, },
    "float" => { type: :float, fieldType: 'float', methodType: 'Float', propgen: ->(name) { "#{name}(\"#{name}\", Float) = 0" }, },
    "float2" => { type: :vector, fieldType: 'Vector2', methodType: 'Vector', propgen: ->(name) { "#{name}(\"#{name}\", Vector) = (0, 0, 0)" }, },
    "float3" => { type: :vector, fieldType: 'Vector3', methodType: 'Vector', propgen: ->(name) { "#{name}(\"#{name}\", Vector) = (0, 0, 0)" }, },
    "float4" => { type: :vector, fieldType: 'Vector4', methodType: 'Vector', propgen: ->(name) { "#{name}(\"#{name}\", Vector) = (0, 0, 0, 0)" }, },
}

keywords = {}
# process keywords
open(keywordsFile) do |f|
    f.each_line do |line|
        line.chomp!
        path, keyword = line.split("\t")
        next if keyword =~ /^UNITY_/
        keywords[keyword] = true
    end
end
keywordValues = keywords.keys.map { |k| { "name" => k } }

dependencyInfo = {}
# process includes (dependency)
open(includeFile) do |f|
    f.each_line do |line|
        line.chomp!
        path, includeFile, _ = line.split("\t")
        dependencyInfo[path] = [] unless dependencyInfo.key? path
        dependencyInfo[path] << includeFile
    end
end

places = {}

props = {}
# process properties
open(propsFile) do |f|
    f.each_line do |line|
        line.chomp!
        path, name, type, _ = line.split("\t")
        proptype = PROPTYPEDEF[type]
        if proptype.nil?
            STDERR.puts "prop type '#{type}' unknown."
            next
        end
        propplace = path
        places[propplace] = true
        props["#{proptype}:#{name}"] = {} unless props.key? "#{proptype}:#{name}"
        props["#{proptype}:#{name}"][propplace] = true
    end
end

proceeds = {}
# process values
open(valsFile) do |f|
    f.each_line do |line|
        line.chomp!
        path, name, type, orgline, context = line.split("\t")

        unless context.nil? || context == ""
            #STDERR.puts "skip(has context): #{name} #{type}: #{context}"
            next
        end

        qtype = type.gsub(/(?:half|fixed)/, "float").gsub(/_(?:half|float)$/, "")
        typedef = TYPEDEF[qtype]
        if typedef.nil?
            STDERR.puts "type '#{qtype}' unknown."
            next
        end

        # ignore scale/offset
        next if name =~ /_ST$/
        # ignore depth/grab texture
        next if typedef[:type] == :Texture && name =~ /\A_(?:Grab|(?:Last)?CameraDepth(?:Normals)?)Texture\z/

        valplace = path
        places[valplace] = true

        proceeds["#{typedef[:type]}:#{name}"] = {} unless proceeds.key?("#{typedef[:type]}:#{name}")
        unless props.key?("#{typedef[:type]}:#{name}") && props["#{typedef[:type]}:#{name}"].key?(valplace)
            unless proceeds["#{typedef[:type]}:#{name}"].key? valplace
                proceeds["#{typedef[:type]}:#{name}"][valplace] = {
                    name: name,
                    type: type,
                    methodType: typedef[:methodType],
                    fieldType: typedef[:fieldType],
                    field: "[Tooltip(\"#{type}\")] public #{typedef[:fieldType]} #{name};",
                    applyGlobal: "#{name} = Shader.GetGlobal#{typedef[:methodType]}(\"#{name}\");",
                    applyMaterial: "if (mat.HasProperty(\"#{name}\")) #{name} = mat.Get#{typedef[:methodType]}(\"#{name}\");",
                    prop: typedef[:propgen].call(name),
                }
            end
        end
    end
end

def extractDependency(dependencyInfo, place)
    [].tap do |x|
        x << place
        if dependencyInfo.key? place
            x.push *(dependencyInfo[place].flat_map do |y| extractDependency(dependencyInfo, y) end)
        end
    end
end

# load inuseGlobalProps data if exists (from Unity)
checkUseYamlFile = "./#{className}_forUnity.yml"
checkUseYamlData = {}
if Pathname(checkUseYamlFile).exist?
    checkUseYamlData = YAML.load_file(checkUseYamlFile)
end
inuseGlobalProps = nil
inuseGlobalProps = checkUseYamlData["inuseGlobalProps"] if checkUseYamlData.key? "inuseGlobalProps"

generated = {}
globalProps = []
fieldDefs = []
applyGlobalValues = []
applyMaterialValues = []

globalPropDef = {}.tap do |propsInfo|
    places.keys.each do |place|
        next if place =~ /\.cginc\z/ # ignore .cginc (output data for .shader file not .cginc)
        next if Pathname(place).basename.to_s =~ %r/^Standalone/ # ignore .shader with Standalone prefix.(it should be generated or works without global values.)
        placesWithDependency = extractDependency(dependencyInfo, place) # extract include dependency
        propsInfo[place] = [].tap do |o|
            proceeds.each do |k, v|
                next if props.key?(k) && placesWithDependency.any? { |x| props[k].key?(x) }
                existsKey = placesWithDependency.find { |x| v.key? x }
                unless existsKey.nil?
                    inuse = inuseGlobalProps.nil? || inuseGlobalProps.any? do |x| x["name"] == v[existsKey][:name] and x["fieldType"] == v[existsKey][:fieldType] end
                    if inuse
                        o << { # per .shader global values informations
                            "name" => v[existsKey][:name],
                            "type" => v[existsKey][:type].to_s,
                            "fieldType" => v[existsKey][:fieldType],
                            "methodType" => v[existsKey][:methodType],
                            "propDef" => v[existsKey][:prop],
                        }
                    end
                    unless generated.key? k
                        generated[k] = true
                        globalProps << {
                            "name" => v[existsKey][:name],
                            "type" => v[existsKey][:type].to_s,
                            "fieldType" => v[existsKey][:fieldType],
                            "methodType" => v[existsKey][:methodType],
                        }

                        if inuse
                            fieldDefs << v[existsKey][:field]
                            applyGlobalValues << v[existsKey][:applyGlobal]
                            applyMaterialValues << v[existsKey][:applyMaterial]
                        end
                    end
                end
            end
        end
    end
end

# output yml data file
ymlData = {}
ymlData["globalPropDef"] = globalPropDef
ymlData["globalProps"] = globalProps
ymlData["proceeds"] = proceeds
ymlData["props"] = props
ymlData["keywords"] = keywordValues
ymlData["inuseGlobalProps"] = inuseGlobalProps unless inuseGlobalProps.nil?
open("./#{className}.yml.tmp", "w") do |f|
    f.print YAML.dump(ymlData)
end
FileUtils.mv("./#{className}.yml.tmp", "./#{className}.yml")

# output yml data file for Unity
checkUseYamlData["globalProps"] = globalProps
checkUseYamlData["keywords"] = keywordValues
checkUseYamlData["inuseGlobalProps"] = inuseGlobalProps.nil? ? globalProps : inuseGlobalProps
open("./#{checkUseYamlFile}.tmp", "w") do |f|
    f.print YAML.dump(checkUseYamlData)
end
FileUtils.mv("./#{checkUseYamlFile}.tmp", "./#{checkUseYamlFile}")

# output debug class
open("./#{className}.cs.tmp", "w") do |f|
    f.print <<"EOT"
using UnityEditor;
using UnityEngine;

namespace Test
{
    public class #{className} : MonoBehaviour
    {
        public Material checkMaterial;
        public bool fromMaterialOnly;

        #{fieldDefs.join("\n        ")}

        private void Update()
        {
            applyValue();
        }

        public void applyValue()
        {
            
            if (!fromMaterialOnly)
            {
                applyGlobalValue();
            }
            if (checkMaterial)
            {
                applyMaterialValue(checkMaterial);
            }
        }

        public void applyGlobalValue()
        {
            #{applyGlobalValues.join("\n            ")}
        }
        private void applyMaterialValue(Material mat)
        {
            #{applyMaterialValues.join("\n            ")}
        }
    }

    #if UNITY_EDITOR
    [CustomEditor(typeof(#{className}))]
    public class #{className}Editor : Editor
    {
        public override void OnInspectorGUI()
        {
            #{className} self = (#{className}) target;
            self.applyValue();
            serializedObject.Update();
            DrawDefaultInspector();
            serializedObject.ApplyModifiedProperties();
        }
    }
    #endif
}
EOT
end
FileUtils.mv("./#{className}.cs.tmp", "./#{className}.cs")
