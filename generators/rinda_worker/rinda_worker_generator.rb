Rails::Generator::Commands::Create.class_eval do
  # refer rails-2.3.8/lib/rails_generator/commands.rb
  def conf_template(relative_source, relative_destination, template_options = {})
    template(relative_source, relative_destination, template_options)
  end
end

Rails::Generator::Commands::Destroy.class_eval do
  def conf_template(relative_source, relative_destination, template_options = {})
    # do nothing
  end
end

class RindaWorkerGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions class_path, "#{class_name}Worker", "#{class_name}WorkerTest"

      # Helper and helper test directories.
      m.directory File.join('app/workers', class_path)
      m.directory File.join('test/unit/workers', class_path)

      # Helper and helper test class.

      m.template 'worker.rb',
                  File.join('app/workers',
                            class_path,
                            "#{file_name}_worker.rb")

      m.template 'worker_test.rb',
                  File.join('test/unit/workers',
                            class_path,
                            "#{file_name}_worker_test.rb")

      worker_config_file = "#{RAILS_ROOT}/config/workers.yml"
      @worker_config = File.exists?(worker_config_file) ? YAML.load_file(worker_config_file) : []
      @worker_config << [[1, file_name, {}]]
      m.conf_template 'workers.yml', 'config/workers.yml'
    end
  end

  def yaml_worker_config
    YAML.dump(@worker_config)
  end
end
