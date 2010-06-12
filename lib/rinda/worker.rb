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
    # Rinda::Worker instance must be initialized with Rinda::TupleSpace instance.
    # Before getting TupleSpace instance, you need to call DRb.start_service.
    def initialize(ts, options = {})
      @ts = ts
      @renewer = Rinda::SimpleRenewer.new # use with default setting (180sec)
      class_name = self.class.to_s.underscore.match(/^([\w_\/]+)_worker/)[1]
      @request = :"#{class_name}_request"
      @executing = :"#{class_name}_executing"
      @done = :"#{class_name}_done"
      @logger = options[:logger]
      if @logger.nil?
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::INFO
      end
      @key = options[:key] || Rinda::Worker.key(DRb.uri, object_id)
    end

    def allowed_instance_methods
      %w(echo exit_worker)
    end

    def main_loop
      logger.info("Start main_loop of #{self.class.to_s}")
      while true
        req_type, req_key, class_name, method_name, options, stream = take_request
        begin
          result = nil
          raise NoMethodError if !allowed_instance_methods.include?(method_name.to_s)
          result = send(method_name.to_s, options)
          stream.push(result) if !stream.nil?
        rescue => error
          logger.error "Error occurred in #{class_name.to_s}.#{method_name.to_s}"
          logger.error "#{error.class}: #{error.message}"
          logger.error error.backtrace
        ensure
          write_done(req_key, class_name, method_name, options, options[:ts_timeout])
        end
      end
    end

    def echo(x)
      logger.info x
    end

    # job requester methods
    def write_request(class_name, method_name, options = {}, stream = nil)
      @ts.write([@request, @key, class_name, method_name, options, stream], renewer)
    end

    def exit_request
      @ts.write([@request, @key, self.class.to_s.to_sym, :exit_worker, {}, nil], renewer)
    end

    def take_done(class_name = nil, method_name = nil, options = nil)
      @ts.take([@done, @key, class_name || Symbol,  method_name || Symbol, options], renewer)
    end

    # job monitoring methods
    def read_request_all(class_name = nil, method_name = nil, options = nil)
      @ts.read_all([@request, @key, class_name || Symbol, method_name || Symbol, options])
    end

    def read_executing_all(class_name = nil, method_name = nil, options = nil)
      @ts.read_all([@executing, @key, class_name || Symbol, method_name || Symbol, options])
    end

    def read_done_all(class_name = nil, method_name = nil, options = nil)
      @ts.read_all([@done, @key, class_name || Symbol, method_name || Symbol, options])
    end

    # job executer (worker) methods
    def take_request
      tuple = @ts.take([@request, nil, Symbol, Symbol, nil, nil], renewer)
      @ts.write([@executing] + tuple[1..(tuple.size - 1)], renewer)
      tuple
    end

    def write_done(req_key, class_name, method_name, options, timeout = 86400)
      tuple = @ts.take([@executing, req_key, class_name, method_name, options, nil], renewer)
      @ts.write([@done, req_key, class_name, method_name, options], timeout)
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

      def to_class_name(worker)
        "#{worker.to_s.classify}Worker"
      end

      def to_class(worker)
        #FIXME
        (eval to_class_name(worker))
      end

      # read all worker tuples of the specified worker class (class_name)
      # on the specified node (uri: default '[^\s]+' this means any uri)
      # from specified tuple space (ts)
      # worker type is a subclass of the Rinda::Worker
      # Example:
      #   Rinda::Worker.read_all(ts, :Analyer, 'druby://localhost:54321')
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
