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

    end
  end
end
