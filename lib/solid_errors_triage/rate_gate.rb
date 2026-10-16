# frozen_string_literal: true

require "active_support"
require "active_support/cache"

module SolidErrorsTriage
  # One rate-spike email per error per quiet period, however long the spike
  # lasts. A loop erroring 10,000 times sends one.
  #
  # Kept in the app's cache, so it holds across processes. An app whose cache
  # keeps nothing (NullStore) gets a store in this process instead, which still
  # holds within a process rather than emailing on every occurrence.
  module RateGate
    def self.claim(error_id, quiet:, cache: default_cache)
      cache.write("solid_errors_triage/rate/#{error_id}", true, unless_exist: true, expires_in: quiet)
    end

    def self.default_cache
      cache = defined?(Rails.cache) && Rails.cache
      return cache if cache && !cache.is_a?(ActiveSupport::Cache::NullStore)

      @fallback ||= ActiveSupport::Cache::MemoryStore.new
    end

    def self.reset! = @fallback = nil
  end
end
