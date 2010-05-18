# initialize ruby standard libraries
require 'uri'

# active_support is required for String#underscorex
# at Rinda::WorkerRunner#initialize and for String#classify
# at Rinda::WorkerRunner#worker_class, worker_class_name

# initialize rubygems libraries
# rubygems is already initialized by rails boot.rb in GemBoot case.
# in VendorBoot case, rubygems is not initialized here.
# So thus require it here.
require 'rubygems'
require 'daemons'

module Rinda
  class WorkerRunner < DRb::Runner
    include Daemonize
    include MonitorMixin

    attr_reader :worker

    # ==== Parameters
    # * +options+ - Options are <tt>:worker</tt>
    #
    # ==== Examples
    #   class SampleRunner < Rinda::WorkerRunner; end
    #
    #   # worker name should be specified by :worker option as String value
    #   options[:worker] = 'analyer'
    #   SampleRunner.new(ARGV, options)
    #
    #   # or specify start up option --worker (-w)
    #   % script/rinda_worker --worker=analyzer
    #
    #   In this case, @worker value becomes :analyzer_worker.
    #
    def initialize(argv, options = {})
      super(argv, options.merge(:log_file => 'rinda_worker.log', :pid_file => 'rinda_worker.pid'))
      logger.formatter = Logger::Formatter.new
      @worker = @options[:worker].to_s.underscore
    end

    def worker_class_name
      Rinda::Worker.to_class_name(worker)
    end

    def worker_class
      Rinda::Worker.to_class(worker)
    end

    def init_env
      # If you need full function of rails, require config/environment here.
      # ==== Example
      #   class RailsWorkerRunner < Rinda::WorkerRunner
      #     def init_env
      #       ENV["RAILS_ENV"] = options[:environment]
      #       require "#{RAILS_ROOT}/config/environment"
      #     end
      #   end
      #
      #   runner = RailsWorkerRunner.new(ARGV, options)
      #   runner.run!
    end

    def create_worker(ts)
      Thread.current[:worker] = nil
      synchronize do
        if @options[:logger_worker]
          uri = URI.parse(DRb.uri)
          # search LoggerWorker running on the same node
          logger_worker = Rinda::Worker.read(ts, :LoggerWorker, uri.scheme + '://' + uri.host + ':\d+')
          Thread.current[:worker] = worker_class.new(ts, :logger => logger_worker[2])
        else
          Thread.current[:worker] = worker_class.new(ts, :logger => logger)
        end
        if @options[:ts_uri].nil?
          provider = Rinda::RingProvider.new(worker_class_name.to_sym, DRbObject.new(Thread.current[:worker]), Thread.current[:worker].key)
          provider.provide
        else
          ts.write([:name, worker_class_name.to_sym, DRbObject.new(Thread.current[:worker]), Thread.current[:worker].key])
        end
      end
      Thread.current[:worker].main_loop
    end

    def create_workers(ts)
      @options[:num_threads].to_i.times do |i|
        Thread.new(ts) { create_worker(ts) }
        logger.info "Starting Rinda Worker on URI '#{DRb.uri}' (Thread No.#{sprintf("%02d", i + 1)})"
      end
    end

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = "Usage: #{self.class.command} [options] #{self.class.operations.join('|')}"

        opts.separator ""

        opts.separator "options:"
        opts.on("-u", "--uri=uri", String, "Runs Rinda Worker on the specified url.", "Default: druby://:0") { |v| @options[:uri] = v }
        opts.on("-c", "--config=file", String, "Use custom configuration file") { |v| @options[:config] = v }
        opts.on("-d", "--daemon", "Make server run as a Daemon.") { @options[:detach] = true }
        opts.on("-e", "--environment=name", String, "Specifies the environment to run this server under (test/development/production).", "Default: development") { |v| @options[:environment] = v }
        opts.on("-l", "--log=file", String, "Specifies log file name for this server.", "Default: rinda_worker.log") { |v| @options[:log_file] = v }
        opts.on("-p", "--pid=file", String, "Specifies pid file name for this server.", "Default: rinda_worker.pid") { |v| @options[:pid_file] = v }
        opts.on("-s", "--ts-uri=uri", String, "Specifies Rinda::TupleSpace Server dRuby URI.") { |v| @options[:ts_uri] = v }
        opts.on("-L", "--logger-worker", "Use LoggerWorker for logging outputs of Workers running on the same node.") do
          if @options[:worker] != :logger_worker
            @options[:logger_worker] = true
          else
            puts "--logger-worker (-L) option can not be used for LoggerWorker itself."
            exit
          end
        end
        opts.on("-O", "--logger-level=level", {"debug" => Logger::DEBUG, "info" => Logger::INFO, "warn" => Logger::WARN, "error" => Logger::ERROR, "fatal" => Logger::FATAL}, "Specifies Logger level (debug, info, warn, error, fatal)") do |v|
          if @options[:logger_worker].nil?
            @options[:logger_level] = v
          else
            puts "--logger-level (-O) option can not be used with --logger-worker (-L) option."
            exit
          end
        end
        opts.on("-t", "--threads=number", String, "Specifies number of worker threads for this server.", "Default: 1") { |v| @options[:num_threads] = v }
        opts.on("-w", "--worker=worker_class", String, "Specifies worker class name in 'underscore' form as rails.", "No default value (or may be specified in start up script)") { |v| @options[:worker] = v.to_s.underscore.to_sym }

        opts.separator ""

        opts.on("-h", "--help", "Show this help message.") { puts opts; exit }
      end
    end

    def cmd_start
      if @options[:detach]
        raise RuntimeError, "PID file '#{pid_file}' is already exist." if File.exist?(pid_file)
        daemonize(log_file)
        #Process.daemon (supported only by Ruby 1.9)
        File.open(pid_file, 'w'){ |f| f.write(Process.pid) }
        ts = nil
        begin
          init_env
          ts = Rinda::WorkerRunner.init_ts(@options.merge(:logger => logger))
        rescue
          File.delete(pid_file) if File.exist?(pid_file)
          exit(1)
        end
        at_exit do
          Rinda::Worker.take_all(ts, worker_class_name.to_sym, DRb.uri)
          File.delete(pid_file) if File.exist?(pid_file)
        end
        create_workers(ts)
        DRb.thread.join

      else
        init_env
        ts = Rinda::WorkerRunner.init_ts(@options.merge(:logger => logger))
        at_exit do
          Rinda::Worker.take_all(ts, worker_class_name.to_sym, DRb.uri)
        end
        create_workers(ts)
        $stdin.gets
      end
    end


    class << self # Class Methods
      def init_ts(options = {})
        logger = options[:logger] || Logger.new(STDOUT)
        DRb.start_service(options[:uri])
        ts = nil
        if options[:ts_uri].nil?
          ts = Rinda::TupleSpaceProxy.new(Rinda::RingFinger.primary)
          logger.info "Connected to a Rinda::TupleSpace via Rinda::RingServer"
        else
          ts = Rinda::TupleSpaceProxy.new(DRbObject.new_with_uri(options[:ts_uri]))
          logger.info "Connected to a Rinda::TupleSpace (#{options[:ts_uri]})"
        end
        ts
      end
    end
  end
end
