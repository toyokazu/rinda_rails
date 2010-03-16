require 'optparse'
require 'timeout'
require 'logger'

module Process
  # Returns +true+ the process identied by +pid+ is running.
  def running?(pid)
    Process.getpgid(pid) != -1
  rescue Errno::ESRCH
    false
  end
  module_function :running?
end

module DRb
  class Runner
    OPERATIONS = %w(start stop restart config)

    # Parsed options
    attr_accessor :options
    attr_accessor :log_file
    attr_accessor :pid_file
    attr_accessor :logger

    # Name of the operation to be runned.
    attr_accessor :operation

    # Arguments to be passed to the command.
    attr_accessor :arguments

    def self.operations
      operations = OPERATIONS
      operations
    end

    def self.command
      File.basename(__FILE__)
    end

    def initialize(argv, options = {})
      @argv = argv

      # Default options values
      @options = options

      parse!

      @logger = Logger.new(STDOUT)
      @logger.level = options[:logger_level] || Logger::INFO
      
      @log_file = "#{RAILS_ROOT}/log/#{options[:log_file]}"
      @pid_file = "#{RAILS_ROOT}/tmp/pids/#{options[:pid_file]}"
    end

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = "Usage: #{self.class.command} [options] #{self.class.operations.join('|')}"
        opts.separator ""
        opts.separator "options:"
        opts.on("-c", "--config=file", String, "Use custom configuration file") { |v| options[:config] = v }
        opts.on("-d", "--daemon", "Make server run as a Daemon.") { options[:detach] = true }
        opts.on("-l", "--log=file", String, "Specifies log file name for this server.", "Default: rinda_worker.log") { |v| options[:log_file] = v }
        opts.on("-O", "--logger-level=level", {"debug" => Logger::DEBUG, "info" => Logger::INFO, "warn" => Logger::WARN, "error" => Logger::ERROR, "fatal" => Logger::FATAL}, "Specifies Logger level (debug, info, warn, error, fatal)") { |v| options[:logger_level] = v }
        opts.on("-p", "--pid=file", String, "Specifies pid file name for this server.", "Default: rinda_worker.pid") { |v| options[:pid_file] = v }
        opts.on("-u", "--uri=uri", String, "Runs Rinda TupleSpace Server or RingServer on the specified url.", "Default: druby://:0") { |v| options[:uri] = v }
        
        opts.separator ""
        
        opts.on("-h", "--help", "Show this help message.") { puts opts; exit }
      end
    end

    def parse!
      parser.parse! @argv
      @operation = @argv.shift
      @arguments = @argv
    end

    def run!
      if self.class.operations.include?(@operation)
        run_command
      elsif @operation.nil?
        puts "Operation required"
        puts @parser
        exit 1
      else
        abort "Unknown operation: #{@operation}. Use one of #{self.class.operations.join(', ')}"
      end
    end

    def run_command
      case @operation
      when 'start'
        cmd_start
      when 'stop'
        cmd_stop
      when 'restart'
        cmd_stop
        cmd_start
      when 'config'
      else
      end
    end

    def cmd_start
    end

    def cmd_stop
      kill
    end

    def pid
      @pid ||= File.exist?(pid_file) ? open(pid_file).read.to_i : nil
    end

    def kill(timeout=60)
      if timeout == 0
        send_signal('INT', timeout)
      else
        send_signal('QUIT', timeout)
      end
    end

    def restart
      send_signal('HUP')
    end

    def send_signal(signal, timeout=60)
      puts "Sending #{signal} signal to process #{pid} ... "
      Process.kill(signal, pid)
      Timeout.timeout(timeout) do
        sleep 0.1 while Process.running?(pid)
      end
    rescue Timeout::Error
      puts "Timeout!"
      force_kill
    rescue Interrupt
      force_kill
    rescue Errno::ESRCH # No such process
      puts "process not found!"
      force_kill
    end

    def force_kill
      puts "Sending KILL signal to process #{pid} ... "
      Process.kill("KILL", pid)
    end
  end
end
