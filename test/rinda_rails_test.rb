require File.expand_path('../test_helper', __FILE__)
require File.expand_path('../../lib/rinda/worker_runner', __FILE__)

#class RindaRailsTest < ActiveSupport::TestCase
class RindaRailsTest < Test::Unit::TestCase
  def rinda_ts_path
    File.expand_path('../../script/rinda_ts', __FILE__)
  end

  def start_rinda_ts
    cmd = "#{rinda_ts_path} --daemon --logger-level=info start"
    `#{cmd}`
  end

  def stop_rinda_ts
    cmd = "#{rinda_ts_path} --daemon --logger-level=info stop"
    `#{cmd}`
  end

  def setup
    @ts = nil
    @logger = Logger.new(nil)
  end

  # Replace this with your real tests.
  def test_the_truth
    assert true
  end

  context "Rinda TupleSpace server" do
    should "be started by rinda_ts -d start" do
      # check no TupleSpace server is running
      @ts = nil
      begin
        @ts = Rinda::WorkerRunner.init_ts(:ring_timeout => 1, :logger => @logger)
      rescue => error
      end
      assert_nil(@ts, 'Other rinda_ts is already running.')
      start_rinda_ts
      sleep 1
      @ts = nil
      begin
        @ts = Rinda::WorkerRunner.init_ts(:ring_timeout => 1, :logger => @logger)
      rescue => error
        assert(false, 'Failed to start rinda_ts.')
      end
    end

    should "be stopped by rinda_ts -d stop" do
      @ts = nil
      begin
        @ts = Rinda::WorkerRunner.init_ts(:ring_timeout => 1, :logger => @logger)
      rescue => error
        assert(false, 'No rinda_ts is running. Failed to test stopping rinda_ts.')
      end
      stop_rinda_ts
      sleep 1
      @ts = nil
      begin
        @ts = Rinda::WorkerRunner.init_ts(:ring_timeout => 1, :logger => @logger)
      rescue => error
      end
      assert_nil(@ts, 'rinda_ts is still running after rinda_ts -d stop.')
    end
  end

end
