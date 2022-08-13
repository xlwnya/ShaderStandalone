#!/usr/bin/env ruby
require 'pathname'

if ARGV.size < 1
  STDERR.puts "Usage: #{$0} File..."
  STDERR.puts "  Extract shader keywords informations from .shader & .cginc files. (by pattern matching (not perfect))"
  STDERR.puts "Example: find . -type f -regex '.*\.\(shader\|cginc\)$' -print0 | xargs -n 1024 -0 grep_shaderkeywords.rb > shaderkeywords.txt"
  exit 1
end

ARGF.each_line do |line|
  line.chomp!
  # TODO: support shader_feature_local?
  if line =~ /^\s*#\s*pragma\s+(?:multi_compile|shader_feature)\s+((?:(?:[A-Za-z0-9_-]+)\s+)*(?:[A-Za-z0-9_-]+))\s*$/
    path = Pathname(ARGF.path).cleanpath.to_s
    keywords = $1.split(/\s+/)
    keywords.reject! { |x| x =~ /^_+$/ }
    keywords.each do |k|
      puts "#{path.gsub(/\t/, " ")}\t#{k}"
    end
  end
end
