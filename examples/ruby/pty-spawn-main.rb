#!/usr/bin/ruby
require 'pty'
require 'expect'

commands = ["puts 'hi'", "a = 1", "puts a"]
cmd = "LANG=C java -jar vendors/jruby-complete-1.7.24.jar -e 'load \"META-INF/jruby.home/bin/jirb\"'"

PTY.spawn(cmd) do |r, w, pid|
  # r is node's stdout/stderr and w is stdin
  r.expect(/(.*)>/m)
  commands.each do |cmd|
    puts "Command: " + cmd
    w.puts cmd
    r.expect(/(.*?)\r\n(.*)\r\n(.*)>/m) { |res|
      puts "Output: " + res[2]
    }
  end
end
