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
      @config = options
      begin
        @jobs = YAML.load_file("#{RAILS_ROOT}/config/cron_jobs.yml")
      rescue => error
        output_error(error, "Can not find cron_jobs.yml. Do notiong.")
      end
    end

    def cron_loop
      logger.info("Start cron_loop of #{self.class.to_s}")
      while true
        sleep(interval)
        logger.debug("before exec_cron_jobs")
        exec_cron_jobs
        logger.debug("after exec_cron_jobs")
      end
    end

    def main_loop
      Thread.new { cron_loop }
      super
    end

    def interval
      if Time.now.sec != 0
        return (@config["interval"] - Time.now.sec)
      end
      @config["interval"]
    end

    def record_start_time(worker_type)
      if @config["worker_record"]
        logger.debug("write start time to worker_record #{worker_type}")
        wr = Rinda::CronWorker.worker_record(worker_type)
        wr.start_at = Time.now
        wr.save
      end
    end

    def record_end_time(worker_type)
      if @config["worker_record"]
        logger.debug("write end time to worker_record #{worker_type}")
        wr = Rinda::CronWorker.worker_record(worker_type)
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
          logger.debug("begin synchronization area of exec_cron_jobs")
          @jobs.each_with_index do |job, i|
            schedule, worker_name, method, options = job
            worker_type = Rinda::Worker.to_class_name(worker_name)
            worker = Rinda::Client.new(worker_name, :ts => @ts, :key => @key, :logger => @logger)
            logger.debug("check job execution time")
            if designated_time?(schedule)
              logger.debug("write job request to tuplespace")
              if worker.read_request_all(method, options).size == 0
                record_start_time(worker_type)
                worker.write_request(method, options)
              else
                logger.info("Previous job request still remains. Do nothing.")
              end
            end
            logger.debug("remove finished job tuples")
            if worker.read_done_all(method, options).size > 0
              # FIXME
              # recorded end time is not precise end time.
              worker.take_done(method, options)
              record_end_time(worker_type)
            end
          end
        rescue => error
          output_error(error, "An error occured during exec_cron_jobs")
        end
      end
    end

    def designated_time?(time)
      Time.now.strftime("%Y-%m-%d-%H-%M-%w") =~ Regexp.new(time.gsub('*', '\d+'))
    end

    class << self # Class Methods
      def worker_record(worker_type, force = true)
        worker_record = nil
        begin
          worker_record = WorkerRecord.first(:conditions => {:worker_type => worker_type})
          if worker_record.nil? && force
            worker_record = WorkerRecord.new(:worker_type => worker_type)
          end
        rescue NameError => e
          logger.warn "NameError: #{e.message}"
          logger.warn e.backtrace
          logger.warn "You need to create WorkerRecord model by rake task (rake worker_record:create) or off the worker_record option in config/workers.yml (worker_record: false)."
          return nil
        end
        worker_record
      end
    end
  end
end
