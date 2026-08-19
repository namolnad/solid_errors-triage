# frozen_string_literal: true

require "rails/railtie"

module SolidErrorsTriage
  class Railtie < ::Rails::Railtie
    config.solid_errors_triage = ActiveSupport::OrderedOptions.new
    config.solid_errors_triage.config_path = "config/solid_errors.yml"

    initializer "solid_errors_triage.configure" do |app|
      SolidErrorsTriage.config.load_file(app.root.join(app.config.solid_errors_triage.config_path))
    end

    initializer "solid_errors_triage.patches" do |app|
      app.config.to_prepare do
        next unless defined?(SolidErrors::Subscriber)

        require "solid_errors_triage/patches"
        SolidErrorsTriage::Patches.apply!
      end
    end

    initializer "solid_errors_triage.job" do
      ActiveSupport.on_load(:active_job) { require "solid_errors_triage/cleanup_job" }
    end
  end
end
