module Rinda
  class CronWorker < Rinda::Worker
    include MonitorMixin
    @@lock_table = {}

    def initialize(ts, options = {})
      super(ts, options)
      @config = YAML.load_file("#{RAILS_ROOT}/config/cron.yml")
    end

    def config
      @config[self.class.to_s.underscore]
    end

    def lock 
      synchronize do
        if @@lock_table[self.class.to_s].nil?
          @@lock_table[self.class.to_s] = self.class.to_s
          return true
        end
        false
      end
    end

    def unlock
      synchronize do
        @@lock_table.delete(self.class.to_s)
      end
    end

    def worker_record
      WorkerRecord.first(:conditions => {:worker_type => self.class.to_s}) || WorkerRecord.new(:worker_type => self.class.to_s)
    end

    def main_loop
      while true
        sleep(interval)
        lock
        if config["record_worker"]
          @worker_record = worker_record
          @worker_record.start_at = Time.now
          @worker_record.save
        end
        cron_job
        if config["record_worker"]
          @worker_record = worker_record
          @worker_record.end_at = Time.now
          @worker_record.save
        end
        unlock
      end
    end

    def interval
      config["interval"]
    end

    def cron_job
    end

    class << self # Class Methods
    end
  end
end
