# frozen_string_literal: true

require "yaml"

module SolidErrorsTriage
  # When an error is worth an email.
  #
  # Solid Errors emails on every occurrence out of the box, which for anything
  # recurring trains you to filter the alerts -- and a filtered alert is the same
  # as no alert. With that switched off it still emails new and reopened errors;
  # these are the rules for everything after.
  class Configuration
    DEFAULT_COUNTS = [ 10, 100, 1_000 ].freeze
    DEFAULT_RATE = { count: 30, window: 300 }.freeze

    attr_accessor :counts, :rate_threshold, :notify_on_resolved, :destroy_after, :normalizers

    def initialize
      @counts = DEFAULT_COUNTS.dup
      @rate_threshold = DEFAULT_RATE.dup
      @notify_on_resolved = true
      # Read by the cleanup job rather than set on Solid Errors, because Solid
      # Errors prunes inline on every hundredth occurrence when it has one, which
      # lands a multi-table delete inside the request that just errored.
      @destroy_after = nil
      @normalizers = []
    end

    def load_file(path)
      return self unless File.exist?(path.to_s)

      apply(YAML.load_file(path.to_s, symbolize_names: true) || {})
    end

    def apply(hash)
      triggers = hash[:notification_triggers] || hash
      lifecycle = triggers[:lifecycle] || {}

      @counts = triggers[:counts] if triggers.key?(:counts)
      @rate_threshold = triggers[:rate_threshold] if triggers.key?(:rate_threshold)
      @notify_on_resolved = lifecycle[:resolved] if lifecycle.key?(:resolved)
      if hash.key?(:destroy_resolved_after_days)
        @destroy_after = Integer(hash[:destroy_resolved_after_days]) * 86_400
      end
      self
    end

    # An app-specific way to collapse noisy messages before fingerprinting.
    # Register one per provider whose errors embed a per-request id:
    #
    #   config.normalize(->(error) { ... }) # returns [message, context] or nil
    def normalize(callable)
      @normalizers << callable
      self
    end

    def notify_on_resolved? = @notify_on_resolved == true
  end
end
