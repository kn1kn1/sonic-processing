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

$log_level = :debug
module HaskapJamLoop
  module Log
    extend self

    LOGLEVEL_DEBUG = 0 unless defined?(LOGLEVEL_DEBUG)
    LOGLEVEL_INFO = 1 unless defined?(LOGLEVEL_INFO)
    LOGLEVEL_WARN = 2 unless defined?(LOGLEVEL_WARN)
    LOGLEVEL_ERROR = 3 unless defined?(LOGLEVEL_ERROR)
    LOGLEVEL_FATAL = 4 unless defined?(LOGLEVEL_FATAL)
    LOGLEVEL_MAP = { debug: LOGLEVEL_DEBUG, info: LOGLEVEL_INFO,
                     warn: LOGLEVEL_WARN, error: LOGLEVEL_ERROR,
                     fatal: LOGLEVEL_FATAL }.freeze unless defined?(LOGLEVEL_MAP)

    @@log_level = LOGLEVEL_MAP[$log_level]

    def log_debug(msg)
      return if @@log_level > LOGLEVEL_DEBUG
      log_path = SonicPi::Util.log_path
      File.open("#{log_path}/debug.log", 'a') do |f|
        f.write("[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}|haskap-jam] #{msg}\n")
      end
    end

    def log_info(msg)
      return if @@log_level > LOGLEVEL_INFO
      puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}|haskap-jam] #{msg}"
    end

    def log_error(msg)
      return if @@log_level > LOGLEVEL_ERROR
      STDERR.puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}|haskap-jam] #{msg}"
    end
  end

  module Util
    extend self
    include HaskapJamLoop::Log

    NUMBER_NAMES = %w(zero one two three four five six
                      seven eight nine).freeze unless defined?(NUMBER_NAMES)

    def read_workspace(workspace_id)
      workspace_file_path = workspace_filepath(workspace_id)
      log_debug "workspace_file_path: #{workspace_file_path}"
      code = read_file(workspace_file_path, 5)
      log_debug "code: #{code}"
      if code.nil? || code.empty?
        msg = 'code is nil or empty!'
        log_error msg
        fail msg
      end
      code
    end

    def extract_workspace_id(source_file_name)
      # source_file_name: "Workspace 0"
      matched = source_file_name.match(/([a-zA-Z]|\s)?(\d)/)
      if matched.nil? || matched[2].nil?
        msg = "source_file_name not matched. source_file_name: #{source_file_name}"
        log_error msg
        fail msg
      end
      workspace_id = matched[2]
      log_debug("workspace_id: #{workspace_id}")
      workspace_id.to_i
    end

    def workspace_filepath(workspace_id)
      file_name = workspace_filename(workspace_id)
      log_debug "file_name: #{file_name}"
      if file_name.nil? || file_name.empty?
        msg = 'file_name is nil or empty!'
        log_error msg
        fail msg
      end

      project_path = SonicPi::Util.project_path
      log_debug "project_path: #{project_path}"
      if project_path.nil? || project_path.empty?
        msg = 'project_path is nil or empty!'
        log_error msg
        fail msg
      end

      project_path + file_name
    end

    def workspace_filename(workspace_id)
      # workspace_id: 0-9
      'workspace_' + number_name(workspace_id.to_i) + '.spi'
    end

    def number_name(i)
      if i < 0
        msg = "can not convert to number name: #{i}"
        log_error msg
        fail msg
      end
      name = NUMBER_NAMES.fetch(i, nil)
      if name.nil?
        msg = "can not convert to number name: #{i}"
        log_error msg
        fail msg
      end
      name
    end

    def read_file(file_path, max_retry)
      code = nil
      rep = 1
      while code.nil? || code.empty? || rep < max_retry
        code = File.read(file_path)
        rep += 1
      end
      code
    end
  end
end

# entry point
include HaskapJamLoop::Log
include HaskapJamLoop::Util
def rp5_inline_sketch(start_option = {})
  source_file_name = caller[0][/[^:]+/]
  log_debug "source_file_name: #{source_file_name}"
  workspace_id = extract_workspace_id(source_file_name)
  code = read_workspace(workspace_id)
  sketch_code = code.gsub(/^(load.*sonic-processing.rb.*$)/, '#\\1')
  sketch_code = sketch_code.gsub(/^(rp5_inline_sketch.*$)/, '#\\1')
  log_debug "sketch_code: #{sketch_code}"
  rp5_sketch(sketch_code, start_option)

  # stop here not to execute inline code
  stop
end
