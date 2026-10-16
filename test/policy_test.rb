# frozen_string_literal: true

require "test_helper"

class PolicyTest < TriageTestCase
  def policy = SolidErrorsTriage.policy

  # The 2nd occurrence tells you nothing the 1st didn't, and the 1st is emailed by
  # Solid Errors itself.
  def test_emails_on_milestones_only
    assert_nil policy.trigger_for(rank: 1)
    assert_nil policy.trigger_for(rank: 2)
    assert_nil policy.trigger_for(rank: 9)
    assert_equal :milestone, policy.trigger_for(rank: 10)
    assert_equal :milestone, policy.trigger_for(rank: 100)
    assert_nil policy.trigger_for(rank: 101)
  end

  # Over, not only exactly on: a count can come back down to the threshold as
  # old occurrences leave the window, so equality fires again and again, and a
  # count that jumped past it would never fire. RateGate keeps this to one email.
  def test_rate_holds_while_the_window_is_over_the_threshold
    assert_nil policy.trigger_for(rank: 5, recent_count: 29)
    assert_equal :rate, policy.trigger_for(rank: 5, recent_count: 30)
    assert_equal :rate, policy.trigger_for(rank: 5, recent_count: 9_999)
  end

  def test_milestone_wins_over_rate
    assert_equal :milestone, policy.trigger_for(rank: 100, recent_count: 30)
  end

  def test_rate_is_disabled_when_unconfigured
    SolidErrorsTriage.configure { |c| c.rate_threshold = {} }
    assert_nil SolidErrorsTriage.policy.trigger_for(rank: 5, recent_count: 500)
  end

  def test_counts_can_be_replaced
    SolidErrorsTriage.configure { |c| c.counts = [ 3 ] }
    assert_nil SolidErrorsTriage.policy.trigger_for(rank: 10)
    assert_equal :milestone, SolidErrorsTriage.policy.trigger_for(rank: 3)
  end

  # "3rd occurrence" and "resolved" get triaged very differently, and the subject
  # is where that decision is made.
  def test_subjects_say_which_rule_fired
    subject = ->(reason, **rest) { policy.subject_for(reason: reason, exception_class: "TimeoutError", severity_emoji: "🔥", **rest) }

    assert_equal "🔥 TimeoutError", subject.(:created)
    assert_equal "🔥 TimeoutError", subject.(nil)
    assert_equal "🔥 TimeoutError (reopened)", subject.(:reopened)
    assert_equal "🔥 TimeoutError (3rd occurrence)", subject.(:milestone, ordinal: "3rd")
    assert_equal "🔥 TimeoutError (rate spike)", subject.(:rate)
    assert_equal "✅ RESOLVED: TimeoutError", subject.(:resolved)
  end
end
