# initialize ruby standard libraries
require 'uri'

require File.expand_path('../../drb/runner',  __FILE__)
require File.expand_path('../../rinda/worker', __FILE__)
require 'rinda/tuplespace'
require 'rinda/ring'

# active_support is required for String#underscore
# at Rinda::WorkerRunner#initialize and for String#classify
# at Rinda::WorkerRunner#worker_class, worker_class_name

# FIXME
# this implementation requires that rails must be installed by rubygems
require 'rubygems'
require 'active_support'
require 'daemons'

module Rinda
  class WorkerRunner < DRb::Runner
    include Daemonize
    include MonitorMixin

    def output_error(error, message)
      logger.error "Error occurred during #{message}."
      logger.error "#{error.class}: #{error.message}"
      logger.error error.backtrace
    end

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
      begin
        Thread.current[:worker] = nil
        synchronize do
          if !@options[:max_instances].nil? &&
            ts.read_all([:name, worker_class_name.to_sym, nil, nil]).size > @options[:max_instances].to_i
            logger.warn("Already specified number of instances/threads (-m or --max-instances option) are found in TupleSpace.")
            exit 1
          end
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
      rescue => error
        output_error(error, "create_workers")
        exit 1
      end
    end

    def create_workers(ts)
      @options[:num_threads].to_i.times do |i|
        Thread.new(ts) { create_worker(ts) }
        logger.info "Starting Rinda Worker on URI '#{DRb.uri}' (Thread No.#{sprintf("%02d", i + 1)})"
      end
    end

    def add_options(opts)
      opts.separator "Rinda::WorkerRunner options:"
      opts.on("-d", "--daemon", "Make server run as a Daemon.") { @options[:detach] = true }
      opts.on("-e", "--environment=name", String, "Specifies the environment to run this server under (test/development/production).", "Default: development") { |v| @options[:environment] = v }
      opts.on("-m", "--max-instances", String, "Specifies max number of instances allowed to register the TupleSpace. Basically used to prevent unnecessary instance start up because of the concurrency issues.", "Default: 5") { |v| @options[:max_instances] = v }
      opts.on("-s", "--ts-uri=uri", String, "Specifies Rinda::TupleSpace Server dRuby URI.") { |v| @options[:ts_uri] = v }
      opts.on("-L", "--logger-worker", "Use LoggerWorker for logging outputs of Workers running on the same node.") do
        if @options[:worker] != :logger_worker
          @options[:logger_worker] = true
        else
          puts "--logger-worker (-L) option can not be used for LoggerWorker itself."
          exit
        end
      end
      opts.on("-t", "--threads=number", String, "Specifies number of worker threads for this server.", "Default: 1") { |v| @options[:num_threads] = v }
      opts.on("-w", "--worker=worker_class", String, "Specifies worker class name in 'underscore' form as rails.", "No default value (or may be specified in start up script)") { |v| @options[:worker] = v.to_s.underscore.to_sym }
      opts.separator ""
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
        begin
          DRb.current_server
        rescue DRb::DRbServerNotFound => error
          logger.info "Can not find any current DRb server. Start up new one."
          DRb.start_service(options[:uri])
        end
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
