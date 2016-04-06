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
#SonicProcessingLiveSketch.new
#SonicProcessingLiveSketch.new(full_screen: true)
SonicProcessingLiveSketch.new(%s)
EOT
$update_sketch_tmpl = <<EOT
class SonicProcessingLiveSketch < Processing::App
  %s
end
EOT
$jruby_jar = $rp_path + '/vendors/jruby-complete-1.7.24.jar'

def start_rp5_sketch(code, option = {})
  puts '*** start_rp5_sketch'
  cmd = "java -jar #{$jruby_jar} -e 'load \"META-INF/jruby.home/bin/jirb\"'"
  stdin, stdout, stderr, wait_thr = Open3.popen3({ 'LANG' => 'C' }, cmd)
  $irb_stdin = stdin
  # sketch_code = "p 'hello'"
  opts = option.collect {|k, v| "#{k}: #{v}"}.join(", ")
  sketch_code = format($start_sketch_tmpl, code, opts)
  # puts sketch_code
  stdin.puts sketch_code
  puts stdout.read
  puts stderr.read
end

def update_rp5_sketch(code)
  puts '*** update_rp5_sketch'
  sketch_code = format($update_sketch_tmpl, code)
  $irb_stdin.puts sketch_code
end

def rp5_sketch(code, start_option = {})
  if $irb_stdin.nil?
    start_rp5_sketch(code, start_option)
  else
    begin
      update_rp5_sketch(code)
    rescue Errno::EPIPE => e
      puts e.message
      if e.message == "Broken pipe"
        start_rp5_sketch(code, start_option)
      else
        fail e
      end
    end
  end
end
