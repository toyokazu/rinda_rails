module Rinda
  class Client < DelegateClass(Rinda::Worker)
    attr_reader :worker

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
    def initialize(worker, options = {})
      ts = Rinda::WorkerRunner.init_ts(options)
      @worker = Rinda::Worker.to_class(worker).new(ts, options)
      super(@worker)
    end
  end
end
