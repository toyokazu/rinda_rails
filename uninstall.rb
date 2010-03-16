# Install hook code here
require 'fileutils'
# copy environment files
FileUtils.rm("#{RAILS_ROOT}/config/rinda_min_environment.rb")
FileUtils.rm("#{RAILS_ROOT}/config/rinda_environment.rb")

# copy script files
FileUtils.rm("#{RAILS_ROOT}/script/rinda_ts")
FileUtils.rm("#{RAILS_ROOT}/script/rinda_logger")
FileUtils.rm("#{RAILS_ROOT}/script/rinda_worker")
FileUtils.rm("#{RAILS_ROOT}/script/rinda_worker_cluster")
