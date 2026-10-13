# frozen_string_literal: true

require "rails/engine"

module SolidErrorsTriage
  # An engine rather than a railtie so the mailer under app/ is autoloaded, and
  # reloaded alongside the Solid Errors mailer it subclasses.
  class Engine < ::Rails::Engine
    config.solid_errors_triage = ActiveSupport::OrderedOptions.new
    config.solid_errors_triage.config_path = "config/solid_errors.yml"

    # Solid Errors still emails the occurrence that creates or reopens an error;
    # every other email is decided here. An app that sets this explicitly wins,
    # and the notifier stays out of the way when it is true.
    initializer "solid_errors_triage.defaults", before: "solid_errors.config" do |app|
      unless app.config.solid_errors.key?(:email_every_occurrence)
        app.config.solid_errors.email_every_occurrence = false
      end
    end

    initializer "solid_errors_triage.configure" do |app|
      SolidErrorsTriage.config.load_file(app.root.join(app.config.solid_errors_triage.config_path))
    end

    initializer "solid_errors_triage.notifications" do
      SolidErrorsTriage::Notifier.subscribe!
    end

    initializer "solid_errors_triage.job" do
      ActiveSupport.on_load(:active_job) { require "solid_errors_triage/cleanup_job" }
    end

    # After initialize, so normalizers registered in config/initializers are seen.
    config.after_initialize do
      SolidErrorsTriage::NormalizingSubscriber.install!
    end
  end
end
