#!/usr/bin/ruby
require 'open3'
require 'pty'
require 'expect'

$use_pty = false
$log_level = :debug

module HaskapJam
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
      return unless defined? SonicPi
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
    include HaskapJam::Log

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
        raise msg
      end
      code
    end

    def extract_workspace_id(source_file_name)
      # source_file_name: "Workspace_one"
      matched = source_file_name.match(/([a-zA-Z]|\s)?_([a-zA-Z]*)$/)
      if matched.nil? || matched[2].nil?
        msg = "source_file_name not matched. source_file_name: #{source_file_name}"
        log_error msg
        raise msg
      end
      workspace_id = matched[2] # one
      log_debug("workspace_id: #{workspace_id}")
      workspace_id
    end

    def workspace_filepath(workspace_id)
      file_name = workspace_filename(workspace_id)
      log_debug "file_name: #{file_name}"
      if file_name.nil? || file_name.empty?
        msg = 'file_name is nil or empty!'
        log_error msg
        raise msg
      end

      project_path = SonicPi::Util.project_path
      log_debug "project_path: #{project_path}"
      if project_path.nil? || project_path.empty?
        msg = 'project_path is nil or empty!'
        log_error msg
        raise msg
      end

      project_path + file_name
    end

    def workspace_filename(workspace_id)
      # workspace_id: zero, one, ... nine
      'workspace_' + workspace_id + '.spi'
    end

    def number_name(i)
      if i < 0
        msg = "can not convert to number name: #{i}"
        log_error msg
        raise msg
      end
      name = NUMBER_NAMES.fetch(i, nil)
      if name.nil?
        msg = "can not convert to number name: #{i}"
        log_error msg
        raise msg
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

include HaskapJam::Log
include HaskapJam::Util

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

Processing::RP_CONFIG = RP_CONFIG
Processing::App::SKETCH_PATH = defined?(ExerbRuntime) ? ExerbRuntime.filepath : $0

class SonicProcessingLiveSketch < Processing::App
  %s
end

SonicProcessingLiveSketch.new(%s)
EOT
$update_sketch_tmpl = <<EOT
class SonicProcessingLiveSketch < Processing::App
  %s
end
EOT
$jruby_jar = $rp_path + '/vendors/jruby-complete-1.7.24.jar'

def ___in_thread(&block)
  if defined? in_thread
    in_thread({}, &block)
  else
    Thread.new(&block)
  end
end

def ___info(msg)
  __info msg if defined? __info
  puts msg
  log_debug msg
end

def ___debug(msg)
  puts msg
  log_debug msg
end

def ___start_rp5_sketch_open3(code, option = {})
  puts '*** start_rp5_sketch - START'
  log_debug '*** start_rp5_sketch - START'
  cmd = "java -jar #{$jruby_jar} -e 'load \"META-INF/jruby.home/bin/jirb\"'"
  stdin, stdout, stderr, wait_thr = Open3.popen3({ 'LANG' => 'C' }, cmd)
  pid = wait_thr[:pid] # pid of the started process.
  puts "pid: #{pid}"
  log_debug "pid: #{pid}"
  $irb_pid = pid
  $irb_stdin = stdin
  # sketch_code = "p 'hello'"
  opts = option.collect { |k, v| "#{k}: #{v}" }.join(', ')
  sketch_code = format($start_sketch_tmpl, code, opts)
  # puts sketch_code
  stdin.puts sketch_code
  log_debug '*** start_rp5_sketch - 0'
  ___in_thread do
    puts stdout.read
  end
  log_debug '*** start_rp5_sketch - 1'
  ___in_thread do
    puts stderr.read
  end
  log_debug '*** start_rp5_sketch - 2'
  puts '*** start_rp5_sketch - END'
  log_debug '*** start_rp5_sketch - END'
end

def ___start_rp5_sketch_pty(code, option = {})
  ___debug '*** start_rp5_sketch'
  cmd = "LANG=C java -jar #{$jruby_jar} -e 'load \"META-INF/jruby.home/bin/jirb\"'"
  begin
    PTY.spawn(cmd) do |stdout, stdin, pid|
      $irb_pid = pid
      ___debug '*** start - spwan'
      $irb_stdin = stdin

      opts = option.collect { |k, v| "#{k}: #{v}" }.join(', ')
      sketch_code = format($start_sketch_tmpl, code, opts)
      ___debug "sketch_code: #{sketch_code}"

      # WORKAROUND for some sketches which do not work properly (ortbit_inline.spi.rb etc)
      #  change to put codes into stdin in a in_thread block.
      ___in_thread do
        sketch_code.each_line {|line|
          ___debug "sketch_code line: #{line}"
          stdin.puts line
        }
        #___debug "sketch_code: #{sketch_code}"
        #stdin.puts sketch_code
      end
      begin
        # Do stuff with the output here. Just printing to show it works
        log_debug '*** 2'
        stdout.each do |line|
          line = line.gsub(/\n$/, '')
          ___info line
        end
      rescue Errno::EIO
        puts 'Errno:EIO error, but this probably just means ' \
               'that the process has finished giving output'
      ensure
        puts '*** end - spwan'
        log_debug '*** end - spwan'
      end
    end
  rescue PTY::ChildExited
    ___debug 'The child process exited!'
  ensure
    ___debug '*** start_rp5_sketch - END'
    stop_rp5_sketch
  end
end

# entry point
def set_use_pty(use_pty)
  $use_pty = use_pty
end

def start_rp5_sketch(code, option = {})
  if $use_pty
    ___in_thread do
      ___start_rp5_sketch_pty(code, option)
    end
  else
    ___start_rp5_sketch_open3(code, option)
  end
end

def update_rp5_sketch(code)
  puts '*** update_rp5_sketch'
  sketch_code = format($update_sketch_tmpl, code)
  $irb_stdin.puts sketch_code
end

def stop_rp5_sketch
  unless $irb_stdin.nil?
    begin
      $irb_stdin.close
    ensure
      $irb_stdin = nil
    end
  end
  return if $irb_pid.nil?
  begin
    Process.kill('KILL', $irb_pid) # SIGKILL (signal 9)
  rescue => e
    puts e.message
  ensure
    $irb_pid = nil
  end
end

def rp5_sketch(code, start_option = {})
  if $irb_stdin.nil?
    start_rp5_sketch(code, start_option)
  else
    begin
      update_rp5_sketch(code)
    rescue Errno::EPIPE => e
      puts e.message
      if e.message == 'Broken pipe'
        stop_rp5_sketch
        start_rp5_sketch(code, start_option)
      else
        raise e
      end
    end
  end
end

def rp5_inline_sketch(start_option = {})
  source_file_name = caller[0][/[^:]+/]
  log_debug "source_file_name: #{source_file_name}"
  workspace_id = extract_workspace_id(source_file_name)
  code = read_workspace(workspace_id)

  # sketch_code = code.gsub(/^(load.*sonic-processing.rb.*$)/, '#\\1')
  # sketch_code = sketch_code.gsub(/^(rp5_inline_sketch.*$)/, '#\\1')
  sketch_code = code.gsub(/^(load.*sonic-processing.rb.*$)/, '')
  sketch_code = sketch_code.gsub(/^(rp5_inline_sketch.*$)/, '')
  sketch_code = sketch_code.gsub(/^(set_use_pty.*$)/, '')

  log_debug "sketch_code: #{sketch_code}"
  rp5_sketch(sketch_code, start_option)

  # stop here not to execute inline code
  stop
end
