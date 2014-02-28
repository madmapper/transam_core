module TransamCore
  class Engine < ::Rails::Engine
    # Add a load path for this specific Engine
    config.autoload_paths += %W(#{Rails.root}/app/calculators)
    config.autoload_paths += %W(#{Rails.root}/app/file_handlers)
    config.autoload_paths += %W(#{Rails.root}/app/jobs)
    config.autoload_paths += %W(#{Rails.root}/app/mixins)
    config.autoload_paths += %W(#{Rails.root}/app/reports)
    config.autoload_paths += %W(#{Rails.root}/app/searches)
    config.autoload_paths += %W(#{Rails.root}/app/services)
    config.autoload_paths += %W(#{Rails.root}/app/uploaders)
  end
end
