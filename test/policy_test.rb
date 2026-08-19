# frozen_string_literal: true

require "test_helper"

class PolicyTest < TriageTestCase
  def policy = SolidErrorsTriage.policy

  # The 2nd occurrence tells you nothing the 1st didn't.
  def test_emails_on_milestones_only
    assert_equal :milestone, policy.trigger_for(occurrence_count: 1)
    assert_nil policy.trigger_for(occurrence_count: 2)
    assert_nil policy.trigger_for(occurrence_count: 9)
    assert_equal :milestone, policy.trigger_for(occurrence_count: 10)
    assert_equal :milestone, policy.trigger_for(occurrence_count: 100)
    assert_nil policy.trigger_for(occurrence_count: 101)
  end

  # The whole point: a loop erroring 10,000 times sends one email, not 10,000.
  def test_rate_fires_once_as_the_window_is_crossed
    assert_nil policy.trigger_for(occurrence_count: 5, recent_count: 29)
    assert_equal :rate, policy.trigger_for(occurrence_count: 5, recent_count: 30)
    assert_nil policy.trigger_for(occurrence_count: 5, recent_count: 31)
    assert_nil policy.trigger_for(occurrence_count: 5, recent_count: 9_999)
  end

  def test_milestone_wins_over_rate
    assert_equal :milestone, policy.trigger_for(occurrence_count: 100, recent_count: 30)
  end

  def test_rate_is_disabled_when_unconfigured
    SolidErrorsTriage.configure { |c| c.rate_threshold = {} }
    assert_nil SolidErrorsTriage.policy.trigger_for(occurrence_count: 5, recent_count: 500)
  end

  def test_counts_can_be_replaced
    SolidErrorsTriage.configure { |c| c.counts = [ 3 ] }
    assert_nil SolidErrorsTriage.policy.trigger_for(occurrence_count: 1)
    assert_equal :milestone, SolidErrorsTriage.policy.trigger_for(occurrence_count: 3)
  end

  def test_lifecycle_transitions
    assert_equal :resolved, policy.lifecycle_trigger(was_resolved: false, resolved: true)
    assert_equal :reopened, policy.lifecycle_trigger(was_resolved: true, resolved: false)
    assert_nil policy.lifecycle_trigger(was_resolved: false, resolved: false)
    assert_nil policy.lifecycle_trigger(was_resolved: true, resolved: true)
  end

  def test_lifecycle_can_be_switched_off
    SolidErrorsTriage.configure { |c| c.notify_on_resolved = false }
    assert_nil SolidErrorsTriage.policy.lifecycle_trigger(was_resolved: false, resolved: true)
    assert_equal :reopened, SolidErrorsTriage.policy.lifecycle_trigger(was_resolved: true, resolved: false)
  end

  # "3rd occurrence" and "resolved" get triaged very differently, and the subject
  # is where that decision is made.
  def test_subjects_say_which_rule_fired
    assert_equal "✅ RESOLVED: TimeoutError",
      policy.subject_for(trigger: :resolved, exception_class: "TimeoutError")
    assert_equal "🔄 REOPENED: TimeoutError",
      policy.subject_for(trigger: :reopened, exception_class: "TimeoutError")
    assert_equal "🔥 TimeoutError (3rd occurrence)",
      policy.subject_for(trigger: :milestone, exception_class: "TimeoutError",
                         severity_emoji: "🔥", occurrence_ordinal: "3rd")
    assert_equal "🔥 TimeoutError (rate spike)",
      policy.subject_for(trigger: :rate, exception_class: "TimeoutError", severity_emoji: "🔥")
  end
end
