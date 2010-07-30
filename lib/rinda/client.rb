require 'delegate'
require File.expand_path('../../rinda/worker',  __FILE__)
require File.expand_path('../../rinda/worker_runner',  __FILE__)

module Rinda
  class Client < DelegateClass(Rinda::Worker)
    attr_reader :worker_client
    attr_reader :worker_class_name

    # ==== Parameters
    # * +worker+ - specify worker class name by under_score form.
    # * +options+ - Options are <tt>:worker</tt>, <tt>:logger</tt>, <tt>:uri</tt>, <tt>:ts_uri</tt>
    #
    # <tt>:logger</tt>  - Logger instance (default Logger.new(STDOUT))
    # <tt>:uri</tt>     - DRbServer uri of this client
    # <tt>:ts_uri</tt>  - Rinda::TupleSpace server uri (default use RingServer to find Rinda::TupleSpace server)
    # <tt>:ts</tt>      - Rinda::TupleSpace remote instance already obtained by Rinda::Worker
    #
    # ==== Examples
    #   client = Rinda::Client.new('analyzer', :ts_uri => 'druby://localhost:54321')
    #   client.write_request(...)
    #   client.take_done(...)
    #
    #   If you use Rinda::Client from Rails environment, you should use
    #   @key value with longer lifetime than DRb.uri and object_id, e.g.
    #   session[:session_id].
    #
    #   client = Rinda::Client.new('analyzer', :key => session[:session_id])
    #
    #   If you use Rinda::Client from Rinda::Worker class, you can reuse
    #   TupleSpace remote instance assigned to Rinda::Worker for Rinda::Client.
    #   In this case, you can also reuse key attribute of Rinda::Worker for
    #   Rinda::Client. Furthermore, Logger output should also shared with
    #   Rinda::Worker.
    #
    #   client = Rinda::Client.new('analyzer', :key => @key, :ts => @ts, :logger => @logger)
    #
    def initialize(worker, options = {})
      ts = options[:ts] || Rinda::WorkerRunner.init_ts(options)
      options.delete(:ts)
      @worker_client = Rinda::Worker.to_class(worker).new(ts, options)
      @worker_class_name = Rinda::Worker.to_class_name(worker)
      super(@worker_client)
    end

    def worker(uri = '[^\s]+')
      # return the reference to the target Worker
      @worker ||= Rinda::Worker.read(ts, @worker_class_name, uri)[2]
    end
  end
end
