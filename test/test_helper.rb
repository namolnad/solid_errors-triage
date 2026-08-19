# frozen_string_literal: true

require "minitest/autorun"
require "solid_errors_triage"

class TriageTestCase < Minitest::Test
  def setup
    SolidErrorsTriage.reset!
  end

  def teardown
    SolidErrorsTriage.reset!
  end
end
