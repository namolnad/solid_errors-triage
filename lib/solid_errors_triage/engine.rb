# frozen_string_literal: true

require "rails/engine"

module SolidErrorsTriage
  # Hooks into the app's boot, some of it before Solid Errors reads its own
  # configuration.
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
      # Named inside the lambda, so a reconfigured policy is the one asked.
      unless app.config.solid_errors.key?(:email_subject)
        app.config.solid_errors.email_subject = ->(**args) { SolidErrorsTriage.subject(**args) }
      end
    end

    initializer "solid_errors_triage.configure" do |app|
      SolidErrorsTriage.config.load_file(app.root.join(app.config.solid_errors_triage.config_path))
    end

    initializer "solid_errors_triage.notifications" do
      SolidErrorsTriage::Notifier.subscribe!
    end

    # Every job and every controller, the framework's own included: a mail
    # delivery job's arguments are the mail.
    initializer "solid_errors_triage.withhold" do
      ActiveSupport.on_load(:active_job) { before_perform { SolidErrorsTriage.withhold_job_arguments! } }
      ActiveSupport.on_load(:action_controller) { before_action { SolidErrorsTriage.withhold_request_params! } }
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
