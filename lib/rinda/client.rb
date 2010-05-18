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
    def initialize(worker, options = {})
      ts = Rinda::WorkerRunner.init_ts(options)
      @worker_client = Rinda::Worker.to_class(worker).new(ts, options)
      @worker_class_name = Rinda::Worker.to_class_name(worker)
      super(@worker_client)
    end

    def worker(uri = '[^\s]+')
      # return the reference to the target Worker
      @worker ||= Rinda::Worker.read(ts, @worker_class_name.to_sym, uri)[2]
    end
  end
end
