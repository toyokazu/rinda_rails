module Rinda
  class CronWorker < Rinda::Worker
    include MonitorMixin

    def output_error(error, message)
      logger.error "Error occurred during #{message}."
      logger.error "#{error.class}: #{error.message}"
      logger.error error.backtrace
    end

    def initialize(ts, options = {})
      super(ts, options)
      begin
        @config = YAML.load_file("#{RAILS_ROOT}/config/cron.yml")
      rescue => error
        output_error(error, "Can not find cron.yml. Use default configuration.")
        @config = {"num_of_instances" => 1, "interval" => 60, "record_worker" => true}
      end
    end

    def worker_record(worker_type)
      WorkerRecord.first(:conditions => {:worker_type => worker_type}) || WorkerRecord.new(:worker_type => worker_type)
    end

    def main_loop
      logger.info("Start main_loop of #{self.class.to_s}")
      while true
        sleep(interval)
        exec_cron_jobs
      end
    end

    def interval
      if Time.now.sec != 0
        return (@config["interval"] - Time.now.sec)
      end
      @config["interval"]
    end

    def record_start_time(worker_type)
      if @config["record_worker"]
        wr = worker_record(worker_type)
        wr.start_at = Time.now
        wr.save
      end
    end

    def record_end_time(worker_type)
      if @config["record_worker"]
        wr = worker_record(worker_type)
        wr.end_at = Time.now
        wr.save
      end
    end

    # Example:
    # - [year-month-day-hour-minute-weekday, class_name, method_name, options]
    # execute SyncWorker.test method at 2010/01/01 12:00
    # - [2010-01-01-12-00-*, sync, test, {param1: 1, param2: hoge}]
    # execute SyncWorker.test method at every Sunday at 07:00
    # - [*-*-*-07-00-0, sync, test, {param1: 1, param2: hoge}]
    def exec_cron_jobs
      synchronize do
        begin
          @jobs = YAML.load_file("#{RAILS_ROOT}/config/cron_jobs.yml")
        rescue => error
          output_error(error, "Can not find cron_jobs.yml. Do notiong.")
          return
        end
        @jobs.each do |job|
          worker_type = Rinda::Worker.to_class_name(job[1])
          if designated_time?(job[0])
            if read_request_all(worker_type.to_sym, job[2].to_sym, job[3]).size == 0
              record_start_time(worker_type)
              write_request(worker_type.to_sym, job[2].to_sym, job[3])
            else
              logger.info("Previous job request still remains. Do nothing.")
            end
          end
          if read_done_all(worker_type.to_sym, job[2].to_sym, job[3]).size > 0
            # FIXME
            # recorded end time is not precise end time.
            take_done(worker_type.to_sym, job[2].to_sym, job[3])
            record_end_time(worker_type)
          end
        end
      end
    end

    def designated_time?(time)
      Time.now.strftime("%Y-%m-%d-%H-%M-%w") =~ Regexp.new(time.gsub('*', '\d+'))
    end

    class << self # Class Methods
      def worker_record(class_name)
        WorkerRecord.first(:conditions => {:worker_type => class_name})
      end
    end
  end
end
