#!/usr/bin/env ruby

require 'fileutils'
require 'yaml'
require 'pathname'

# for RTPv3 ver.
# ・disable LOD
# ・add addshadow & fullforwardshadows for surface shader with decal:blend

if ARGV.size < 3
  STDERR.puts "Usage: #{$0} className filePrefix shaderPrefix"
  STDERR.puts "className = debug class basename. className.yml should be exists."
  STDERR.puts "filePrefix = filename prefix for standalone shader."
  STDERR.puts "shaderPrefix = shader name prefix for standalone shader."
  STDERR.puts "  Create standalone shader from original .shader files. (get global values from material properties.)"
  STDERR.puts "Example: make_shader_standalone_rtpv3.rb Debug Standalone Test/Standalone"
  exit 1
end

className = ARGV.shift
filePrefix = ARGV.shift
shaderPrefix = ARGV.shift

def indentLevel(line)
  indentTabWidth = 4
  level = 0
  if line =~ /^(\s*)/
    level = $1.gsub(/\t/, " "*indentTabWidth).size
  end
  level
end

yamlFile = "./#{className}.yml"
yamlData = {}
exit 1 unless Pathname(yamlFile).exist?

yamlData = YAML.load_file(yamlFile)

yamlData["globalPropDef"].each do |fn, filedefs|
  filename = Pathname(fn)
  open(filename) do |f|
    modPath = filename.dirname / "#{filePrefix}#{filename.basename}"
    open(modPath, "w") do |out|
      propDone = false
      contextlevel = 0
      context = ""
      f.each_line do |line|
        line.chomp!
        level = indentLevel(line)
        lineIndent = ""
        if line =~ /^(\s*)/
          lineIndent = $1
        end
        if line =~ /^Shader "([^"]*)"/
          origShaderName = $1
          line.sub!(/^\s*Shader\s*"[^"]*"/, "#{lineIndent}Shader \"#{shaderPrefix}#{origShaderName}\"")
          out.puts line
          next
        end
        if line =~ /^\s*LOD\s*[0-9]+\s*$/
          out.puts "//#{line}"
          next
        end
        if line =~ /^\s*CustomEditor\s*"[^"]*"\s*$/
          out.puts "//#{line}"
          next
        end
        if line =~ /^\s*Dependency\s*"([^"]*)"\s*=\s*"([^"]*)"\s*$/
          shaderName = $1
          shaderFullName = $2
          out.puts "#{lineIndent}Dependency \"#{shaderName}\" = \"#{shaderPrefix}#{shaderFullName}\""
          next
        end
        if line =~ /^\s*#pragma\s+surface\s+[A-Za-z0-9_-]+\s+[A-Za-z0-9_-]+\s+([\sA-Za-z0-9:_-]*)\s*$/
          surfaceOptions = $1.strip.split(/\s+/)
          if surfaceOptions.include? "decal:blend"
            line += " addshadow" unless surfaceOptions.include? "addshadow"
            line += " fullforwardshadows" unless surfaceOptions.include? "fullforwardshadows"
          end
          out.puts line
          next
        end
        if context.size <= 0 || level <= contextlevel
          if !propDone &&line =~ /^\s*Properties\s*/
            contextlevel = level
            context = "Properties"
          end
          if "Properties" == context && line =~ /^\s*\}\s*$/
            propDone = true
            context = ""
            out.puts ""
            out.puts "#{lineIndent}// Add for standalone"
            filedefs.each do |d|
              out.puts "#{lineIndent}#{d["propDef"]}"
            end
            out.puts line
            next
          end
        end
        if "Properties" == context
          line.sub!(/\[HideInInspector\]/, "")
          if line =~ /^\s*([A-Za-z0-9_-]+)\s*\(\"\",/
            propName = $1
            line.sub!(/^\s*([A-Za-z0-9_-]+)\s*\(\"\",/, "#{lineIndent}#{propName} (\"#{propName}\",")
          end
        end
        out.puts line
      end
    end
  end
end
