# frozen_string_literal: true

require "test_helper"

class RateGateTest < TriageTestCase
  def test_one_email_per_error_per_quiet_period
    cache = ActiveSupport::Cache::MemoryStore.new

    assert SolidErrorsTriage::RateGate.claim(1, quiet: 3_600, cache: cache)
    refute SolidErrorsTriage::RateGate.claim(1, quiet: 3_600, cache: cache)
    assert SolidErrorsTriage::RateGate.claim(2, quiet: 3_600, cache: cache), "another error has its own"
  end

  # A NullStore claims every time, which would email on every occurrence.
  def test_a_cache_that_keeps_nothing_is_not_used
    rails = Module.new { def self.cache = ActiveSupport::Cache::NullStore.new }
    Object.const_set(:Rails, rails) unless defined?(::Rails)
    skip "Rails is loaded; covered in the host app" unless ::Rails.equal?(rails)

    assert SolidErrorsTriage::RateGate.claim(1, quiet: 3_600)
    refute SolidErrorsTriage::RateGate.claim(1, quiet: 3_600)
  ensure
    Object.send(:remove_const, :Rails) if defined?(::Rails) && ::Rails.equal?(rails)
  end
end
