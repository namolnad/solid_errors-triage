# frozen_string_literal: true

require "solid_errors_triage/version"
require "solid_errors_triage/configuration"
require "solid_errors_triage/policy"
require "solid_errors_triage/rate_gate"

if defined?(::Rails::Engine)
  require "solid_errors"
  require "solid_errors_triage/engine"
end

module SolidErrorsTriage
  autoload :Notifier, "solid_errors_triage/notifier"
  autoload :NormalizingSubscriber, "solid_errors_triage/normalizing_subscriber"
  autoload :CleanupJob, "solid_errors_triage/cleanup_job"

  # What stands in for withheld job arguments and request params.
  WITHHELD = "[withheld]"

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
      @policy = nil
    end

    def policy
      @policy ||= Policy.new(config)
    end

    def reset!
      @config = nil
      @policy = nil
      RateGate.reset!
    end

    # Set as Solid Errors' email_subject, for its own emails and Notifier's alike.
    # Solid Errors puts email_subject_prefix in front.
    def subject(error:, occurrence:, reason:)
      ordinal = error.occurrences.where(id: ..occurrence.id).count.ordinalize if reason == :milestone
      policy.subject_for(reason: reason, exception_class: error.exception_class,
                         severity_emoji: error.severity_emoji, ordinal: ordinal)
    end

    # Solid Errors fills in arguments and params only where the error context has
    # none, so a placeholder set before the work starts is what it keeps.
    def withhold_job_arguments!
      Rails.error.set_context(arguments: WITHHELD) if config.withhold_job_arguments
    end

    def withhold_request_params!
      Rails.error.set_context(params: WITHHELD) if config.withhold_request_params
    end

    # Runs the registered normalizers. Each one takes the error and returns
    # [replacement_message, extra_context] or nil.
    #
    # This is here because fingerprinting on a message that embeds a per-request
    # id produces one "error" per API call, which buries a real outage under
    # thousands of singletons. Which provider does that is app-specific, so the
    # rule is registered rather than baked in.
    def normalize(error, context)
      config.normalizers.reduce(context || {}) do |acc, normalizer|
        message, extra = normalizer.call(error)
        next acc if message.nil?

        error.define_singleton_method(:message) { message }
        acc.merge(extra || {})
      end
    end
  end
end
