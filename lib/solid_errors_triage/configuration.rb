# frozen_string_literal: true

require "yaml"

module SolidErrorsTriage
  # When an error is worth an email.
  #
  # Solid Errors emails on every occurrence out of the box, which for anything
  # recurring trains you to filter the alerts -- and a filtered alert is the same
  # as no alert.
  class Configuration
    DEFAULT_COUNTS = [ 1, 10, 100, 1_000 ].freeze
    DEFAULT_RATE = { count: 30, window: 300 }.freeze

    attr_accessor :counts, :rate_threshold, :notify_on_resolved, :notify_on_reopened,
                  :store_in_development, :prune_inline, :normalizers

    def initialize
      @counts = DEFAULT_COUNTS.dup
      @rate_threshold = DEFAULT_RATE.dup
      @notify_on_resolved = true
      @notify_on_reopened = true
      # Local exceptions are a firehose -- every typo in a view -- and persisting
      # them makes the errors page useless for the thing it is for.
      @store_in_development = false
      # The gem prunes resolved errors inline on every hundredth occurrence, which
      # lands a multi-table delete inside the request that just errored. The
      # cleanup job does it nightly instead.
      @prune_inline = false
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
      @notify_on_reopened = lifecycle[:reopened] if lifecycle.key?(:reopened)
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
    def notify_on_reopened? = @notify_on_reopened == true
    def store_in_development? = @store_in_development == true
    def prune_inline? = @prune_inline == true
  end
end
