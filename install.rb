# Install hook code here
require 'fileutils'
# copy library files
FileUtils.cp_r(File.expand_path('../lib/drb', __FILE__),
             "#{RAILS_ROOT}/lib/")
FileUtils.cp_r(File.expand_path('../lib/rinda', __FILE__),
             "#{RAILS_ROOT}/lib/")

# copy environment files
FileUtils.cp(File.expand_path('../config/rinda_min_environment.rb', __FILE__),
             "#{RAILS_ROOT}/config/")
FileUtils.cp(File.expand_path('../config/rinda_environment.rb', __FILE__),
             "#{RAILS_ROOT}/config/")

# copy config sample files
FileUtils.cp(File.expand_path('../config/cron.yml.sample', __FILE__),
             "#{RAILS_ROOT}/config/")
FileUtils.cp(File.expand_path('../config/cron_jobs.yml.sample', __FILE__),
             "#{RAILS_ROOT}/config/")

# copy script files
FileUtils.cp(File.expand_path('../script/rinda_ts', __FILE__),
             "#{RAILS_ROOT}/script/")
FileUtils.cp(File.expand_path('../script/rinda_worker', __FILE__),
             "#{RAILS_ROOT}/script/")
FileUtils.cp(File.expand_path('../script/rinda_worker_cluster', __FILE__),
             "#{RAILS_ROOT}/script/")

# show README
puts IO.read(File.expand_path('../README', __FILE__))
