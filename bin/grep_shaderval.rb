#!/usr/bin/env ruby
require 'pathname'

if ARGV.size < 1
  STDERR.puts "Usage: #{$0} File..."
  STDERR.puts "  Extract shader variables informations from .shader & .cginc files. (by pattern matching (not perfect))"
  STDERR.puts "  Currently, some types ex.TEX2DARRAY not supported."
  STDERR.puts "Example: find . -type f -regex '.*\.\(shader\|cginc\)$' -print0 | xargs -n 1024 -0 grep_shaderval.rb > shaderval.txt"
  exit 1
end

context = ""
def indentLevel(line)
  indentTabWidth = 4
  level = 0
  if line =~ /^(\s*)/
    level = $1.gsub(/\t/, " "*indentTabWidth).size
  end
  level
end

contextlevel = 0
ARGF.each_line do |line|
  line.chomp!
  level = indentLevel(line)
  if context.size <= 0 || level <= contextlevel
    if line =~ /^\s*(?:inline\s+)?[A-Za-z0-9_-]+\s+[A-Za-z0-9_-]+\s*\(/
      context = line.sub(/^\s+/, "")
      contextlevel = level
    end
    if line =~ /^\s*struct\s*[A-Za-z0-9_-]+\s*/
      context = line.sub(/^\s+/, "")
      contextlevel = level
    end
    if line =~ /^\s*\}\s*(?:;\s*)?$/
      context = ""
    end
  end
  if line =~ /^\s*(?:uniform\s*)?([A-Za-z0-9_-]+)\s+([A-Za-z0-9_-]+\s*(?:,\s*[A-Za-z0-9_-]+\s*)*);/
    path = Pathname(ARGF.path).cleanpath.to_s
    type = $1
    nameList = $2
    nameList.gsub!(/\s+/, "")
    nameList = nameList.split(",")
    line.sub!(/^\s+/, "")
    next if %w(return v2f Input).include?(type)
    next if context.size > 0
    nameList.each do |name|
      puts "#{path.gsub(/\t/, " ")}\t#{name}\t#{type}\t#{line.gsub(/\t/, " ")}\t#{context.gsub(/\t/, " ")}"
    end
  end

  # TODO: support other types
  if line =~ /^\s*UNITY_DECLARE_TEX2D[A-Za-z0-9_-]+\s*\(\s*([A-Za-z0-9_-]+)\s*\)\s*;/
    path = Pathname(ARGF.path).cleanpath.to_s
    type = 'sampler2D'
    name = $1
    line.sub!(/^\s+/, "")
    next if %w(return v2f Input).include?(type)
    next if context.size > 0
    puts "#{path.gsub(/\t/, " ")}\t#{name}\t#{type}\t#{line.gsub(/\t/, " ")}\t#{context.gsub(/\t/, " ")}"
  end
end
