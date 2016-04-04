#!/usr/bin/ruby
require 'open3'

$rp_path = File.expand_path(File.dirname(__FILE__) + '/vendors/ruby-processing-2.6.17')
puts $rp_path
$rc_file = File.expand_path(File.dirname(__FILE__) + '/rp5rc')
puts $rc_file
$start_sketch_tmpl = <<EOT
require 'psych'
CONFIG_FILE_PATH = '#{$rc_file}'
RP_CONFIG = (Psych.load_file(CONFIG_FILE_PATH))

load '#{$rp_path}/lib/ruby-processing.rb'
load '#{$rp_path}/lib/ruby-processing/app.rb'

class SonicProcessingLiveSketch < Processing::App
  %s
end

Processing::RP_CONFIG = RP_CONFIG
Processing::App::SKETCH_PATH = defined?(ExerbRuntime) ? ExerbRuntime.filepath : $0
SonicProcessingLiveSketch.new(x: 10, y: 30)
EOT
$update_sketch_tmpl = <<EOT
class SonicProcessingLiveSketch < Processing::App
  %s
end
EOT
$jruby_jar = $rp_path + '/vendors/jruby-complete-1.7.24.jar'

def start_sketch(code)
  puts '*** start_sketch'
  cmd = "java -jar #{$jruby_jar} -e 'load \"META-INF/jruby.home/bin/jirb\"'"
  stdin, stdout, stderr, wait_thr = Open3.popen3({ 'LANG' => 'C' }, cmd)
  $irb_stdin = stdin
  # sketch_code = "p 'hello'"
  sketch_code = format($start_sketch_tmpl, code)
  # puts sketch_code
  stdin.puts sketch_code
  puts stdout.read
  puts stderr.read
end

def update_sketch(code)
  puts '*** update_sketch'
  sketch_code = format($update_sketch_tmpl, code)
  $irb_stdin.puts sketch_code
end
