#!/usr/bin/env ruby
require 'pathname'

if ARGV.size < 1
  STDERR.puts "Usage: #{$0} File..."
  STDERR.puts "  Extract shader properties informations from .shader & .cginc files. (by pattern matching (not perfect))"
  STDERR.puts "Example:  find . -type f -regex '.*\.\(shader\|cginc\)$' -print0 | xargs -n 1024 -0 grep_shaderprops.rb > shaderprops.txt"
  exit 1
end

ARGF.each_line do |line|
  line.chomp!
  if line =~ /^\s*(?:\[[^\]]+\]\s*)*([A-Za-z0-9_-]+)\s*\(\s*"[^"]*"\s*,\s*([A-Za-z0-9]+)\s*(?:\(\s*[-0-9\.]+\s*(?:,\s*[-0-9\.]+\s*)*\))?\)\s*=/
    path = Pathname(ARGF.path).cleanpath.to_s
    name = $1
    type = $2
    line.sub!(/^\s+/, "")
    puts "#{path.gsub(/\t/, " ")}\t#{name}\t#{type}\t#{line.gsub(/\t/, " ")}"
  end
end
