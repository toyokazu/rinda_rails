# desc "Explaining what the task does"
# task :rinda_rails do
#   # Task goes here
# end

namespace :worker_record do
  # FIXME
  # copied from rails_generator/commands.rb
  def gsub_file(relative_destination, regexp, *args, &block)
    path = File.join(RAILS_ROOT, relative_destination)
    content = File.read(path).gsub(regexp, *args, &block)
    File.open(path, 'wb') { |file| file.write(content) }
  end

  def migration_file(model)
    Dir.glob("#{RAILS_ROOT}/db/migrate/*_#{model.pluralize}.rb").first.match(/db\/migrate\/[^\s]+.rb/).to_s
  end

  def add_versioned_and_paranoid(model)
    sentinel = "class #{model.classify} < ActiveRecord::Base"
    gsub_file "app/models/#{model}.rb", /(#{Regexp.escape(sentinel)})/mi do |match|
      "#{match}\n  acts_as_versioned\n  acts_as_paranoid"
    end
  end

  # FIXME
  def add_version_table_migration(model)
    up_sentinel = '^(\s+t.timestamps\n)(\s+)(end\n)'
    gsub_file migration_file(model), /#{up_sentinel}/mi do |match|
      "#{match}    #{model.classify}.create_versioned_table\n"
    end
    down_sentinel = '^(\s+)(def\s+self\.down\n)'
    gsub_file migration_file(model), /#{down_sentinel}/mi do |match|
      "#{match}    #{model.classify}.create_versioned_table\n"
    end
  end

  desc "Initialize worker_record model"
  task :create do
    begin
      cmd = "#{RAILS_ROOT}/script/generate model worker_record worker_type:string start_at:timestamp end_at:timestamp deleted_at:timestamp"
      puts cmd
      puts `#{cmd}`
      add_versioned_and_paranoid('worker_record')
      add_version_table_migration('worker_record')
    rescue => error
      puts "Error occurred in initializing worker_record model."
      puts "#{error.class}: #{error.message}"
      puts error.backtrace
    end
  end

  desc "Destroy worker_record model"
  task :destroy do
    begin
      cmd = "#{RAILS_ROOT}/script/destroy model worker_record worker_type:string start_at:timestamp end_at:timestamp deleted_at:timestamp"
      puts cmd
      puts `#{cmd}`
    rescue => error
      puts "Error occurred in destroying worker_record model."
      puts "#{error.class}: #{error.message}"
      puts error.backtrace
    end
  end
end
