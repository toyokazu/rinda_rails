require 'monitor'
require 'logger'

# for using to_underscore method
require 'rubygems'
require 'active_support'

module Rinda
  class Stream
    include MonitorMixin
    def initialize(block)
      super()
      @block = block
    end

    def async_push(x)
      @block.call(x)
    end

    def push(x)
      synchronize do
        @block.call(x)
      end
    end
  end

  class Worker
    attr_reader :ts, :renewer, :key, :logger
    ACCEPT_METHODS = %w(echo)

    def accept_options(options = {})
      options
    end

    # Rinda::Worker instance must be initialized with Rinda::TupleSpace instance.
    # Before getting TupleSpace instance, you need to call DRb.start_service.
    def initialize(ts, options = {})
      @ts = ts
      @renewer = Rinda::SimpleRenewer.new # use with default setting (180sec)
      @underscore_name = Rinda::Worker.to_underscore(self.class.to_s)
      @request = :"#{@underscore_name}_request"
      @executing = :"#{@underscore_name}_executing"
      @done = :"#{@underscore_name}_done"
      @logger = options[:logger]
      if @logger.nil?
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::INFO
      end
      @key = options[:key] || Rinda::Worker.key(DRb.uri, object_id)
      @accept_methods = options["accept_methods"] || ACCEPT_METHODS
      # always add exit_worker to handle exit_request
      @accept_methods << "exit_worker"
      @accept_methods_regexp = /(#{@accept_methods.join('|')})/
      @accept_options = accept_options(options["accept_options"])
      logger.debug(@accept_methods.inspect)
      logger.debug(@accept_options.inspect)
    end

    def main_loop
      logger.info("Start main_loop of #{self.class.to_s}")
      while true
        req_type, req_key, method_name, options, stream = take_request
        begin
          result = nil
          raise NoMethodError if !@accept_methods.include?(method_name.to_s)
          result = send(method_name.to_s, options)
          stream.push(result) if !stream.nil?
        rescue => error
          logger.error "Error occurred in main_loop of #{self.class.to_s} for calling method #{method_name.to_s}"
          logger.error "#{error.class}: #{error.message}"
          logger.error error.backtrace
        ensure
          write_done(req_key, method_name, options, options[:ts_timeout])
        end
      end
    end

    def echo(x)
      logger.info x
    end

    # job requester methods
    def write_request(method_name, options = {}, stream = nil)
      @ts.write([@request, @key, method_name, options, stream], renewer)
    end

    def exit_request
      @ts.write([@request, @key, "exit_worker", {}, nil], renewer)
    end

    def take_done(method_name = nil, options = nil)
      @ts.take([@done, @req_key, method_name, options], renewer)
    end

    # job monitoring methods
    # EXAMPLE
    #   client = Rinda::Client.new('target_worker')
    #   # check requests to the target_worker
    #   client.read_request_all
    def read_request_all(method_name = nil, options = nil)
      @ts.read_all([@request, nil, method_name || @accept_methods_regexp, options || @accept_options, nil])
    end

    def read_executing_all(method_name = nil, options = nil)
      @ts.read_all([@executing, nil, method_name || @accept_methods_regexp, options || @accept_options, nil])
    end

    def read_done_all(method_name = nil, options = nil)
      @ts.read_all([@done, nil, method_name || @accept_methods_regexp, options || @accept_options])
    end

    # job executer (worker) methods
    def take_request
      tuple = @ts.take([@request, nil, @accept_methods_regexp, @accept_options, nil], renewer)
      @ts.write([@executing] + tuple[1..(tuple.size - 1)], renewer)
      tuple
    end

    def write_done(req_key, method_name, options, timeout = 86400)
      tuple = @ts.take([@executing, req_key, method_name, options, nil], renewer)
      @ts.write([@done, req_key, method_name, options], timeout)
      tuple
    end

    def exit_worker(options = {})
      #FIXME
      exit
    end

    class << self # Class Methods
      def key(uri, obj_id)
        "#{uri}/#{obj_id}"
      end

      def to_underscore(class_name)
        class_name.underscore.match(/^([\w_\/]+)_worker/)[1]
      end

      def to_class_name(worker)
        "#{worker.to_s.classify}Worker"
      end

      def to_class(worker)
        #FIXME
        (eval to_class_name(worker))
      end

      # exit_request used at rinda_ts exit phase
      def exit_request(ts, class_name, renewer = Rinda::SimpleRenewer.new)
        underscore_name = Rinda::Worker.to_underscore(class_name)
        request = :"#{underscore_name}_request"
        ts.write([request, nil, "exit_worker", {}, nil], renewer)
      end

      # read all worker tuples of the specified worker class (class_name)
      # on the specified node (uri: default '[^\s]+' this means any uri)
      # from specified tuple space (ts)
      # worker type is a subclass of the Rinda::Worker
      # Example:
      #   Rinda::Worker.read_all(ts, "Analyer", 'druby://localhost:54321')
      def read_all(ts, class_name, uri = '[^\s]+')
        ts.read_all([:name, class_name, nil, Regexp.new(uri + '/\d+')])
      end

      # take all worker tuples of the specified worker class (class_name)
      # on the specified node (uri: default '[^\s]+' this means any uri)
      # from specified tuple space (ts)
      def take_all(ts, class_name, uri = '[^\s]+')
        target = [:name, class_name, nil, Regexp.new(uri + '/\d+')]
        ts.take(target) while !ts.read_all(target).empty?
      end

      # read a worker tuple of the specified worker class (class_name)
      # on the specified node (uri: default '[^\s]+' this means any uri)
      # from specified tuple space (ts)
      # this method will wait until ts.read get a response
      def read(ts, class_name, uri = '[^\s]+')
        ts.read([:name, class_name, nil, Regexp.new(uri + '/\d+')])
      end

      # take a worker tuple of the specified worker class (class_name)
      # on the specified node (uri: default '[^\s]+' this means any uri)
      # from specified tuple space (ts)
      # this method will wait until ts.take get a response
      def take(ts, class_name, uri = '[^\s]+')
        ts.take([:name, class_name, nil, Regexp.new(uri + '/\d+')])
      end
    end
  end
end
