# frozen_string_literal: true

require "solid_errors_triage/version"
require "solid_errors_triage/configuration"
require "solid_errors_triage/policy"

if defined?(::Rails::Engine)
  require "solid_errors"
  require "solid_errors_triage/engine"
end

module SolidErrorsTriage
  autoload :Notifier, "solid_errors_triage/notifier"
  autoload :NormalizingSubscriber, "solid_errors_triage/normalizing_subscriber"
  autoload :CleanupJob, "solid_errors_triage/cleanup_job"

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
