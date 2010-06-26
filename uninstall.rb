# Install hook code here
require 'fileutils'
# remove environment files
FileUtils.rm_r "#{RAILS_ROOT}/lib/drb", :force => true
FileUtils.rm_r "#{RAILS_ROOT}/lib/rinda", :force => true

# remove environment files
FileUtils.rm "#{RAILS_ROOT}/config/rinda_min_environment.rb", :force => true
FileUtils.rm "#{RAILS_ROOT}/config/rinda_environment.rb", :force => true

# remove config sample files
FileUtils.rm "#{RAILS_ROOT}/config/cron.yml.sample", :force => true
FileUtils.rm "#{RAILS_ROOT}/config/cron_jobs.yml.sample", :force => true

# remove script files
FileUtils.rm "#{RAILS_ROOT}/script/rinda_ts", :force => true
FileUtils.rm "#{RAILS_ROOT}/script/rinda_logger", :force => true
FileUtils.rm "#{RAILS_ROOT}/script/rinda_worker", :force => true
FileUtils.rm "#{RAILS_ROOT}/script/rinda_worker_cluster", :force => true
