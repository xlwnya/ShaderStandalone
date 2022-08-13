#!/usr/bin/env ruby
require 'pathname'

if ARGV.size < 1
  STDERR.puts "Usage: #{$0} currentDir File..."
  STDERR.puts "currentDir = Current directory path from unity project base dir. 'Assets/～'"
  STDERR.puts "  Extract shader include informations from .shader & .cginc files. (by pattern matching (not perfect))"
  STDERR.puts "Example: find . -type f -regex '.*\.\(shader\|cginc\)$' -print0 | xargs -n 1024 -0 grep_include.rb Assets/xxx/yyy > shaderinclude.txt"
  exit 1
end

fromProjectBase = ARGV.shift

ARGF.each_line do |line|
  line.chomp!
  if line =~ /^\s*#include\s*"([^"]*)"\s*$/
    path = Pathname(ARGF.path).cleanpath
    includePath = $1
    if includePath =~ %r!^#{Regexp.escape(fromProjectBase)}!
      includePath.sub!(%r!^#{Regexp.escape(fromProjectBase)}/?!, "")
      includePath = Pathname(includePath)
    else
      includePath = path.dirname / includePath
    end
    includePath = includePath.cleanpath
    next unless includePath.exist?
    line.sub!(/^\s+/, "")
    puts "#{path.to_s.gsub(/\t/, " ")}\t#{includePath.to_s}\t#{line.gsub(/\t/, " ")}"
  end
end
