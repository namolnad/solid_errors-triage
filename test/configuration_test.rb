# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < TriageTestCase
  def test_sensible_defaults
    config = SolidErrorsTriage.config

    # Solid Errors itself emails the first occurrence.
    assert_equal [ 10, 100, 1_000 ], config.counts
    assert config.notify_on_resolved?
    assert_nil config.destroy_after
  end

  def test_loads_a_yaml_file
    path = File.expand_path("tmp_solid_errors.yml", __dir__)
    File.write(path, <<~YAML)
      notification_triggers:
        lifecycle:
          resolved: false
        counts: [2, 20]
        rate_threshold:
          count: 5
          window: 60
      destroy_resolved_after_days: 90
    YAML

    SolidErrorsTriage.config.load_file(path)

    assert_equal [ 2, 20 ], SolidErrorsTriage.config.counts
    assert_equal({ count: 5, window: 60 }, SolidErrorsTriage.config.rate_threshold)
    refute SolidErrorsTriage.config.notify_on_resolved?
    assert_equal 90 * 86_400, SolidErrorsTriage.config.destroy_after
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  def test_a_missing_file_leaves_the_defaults_alone
    SolidErrorsTriage.config.load_file("/nowhere/solid_errors.yml")
    assert_equal [ 10, 100, 1_000 ], SolidErrorsTriage.config.counts
  end

  # Fingerprinting on a message with a per-request id in it produces one "error"
  # per API call, which buries a real outage under thousands of singletons.
  def test_normalizers_rewrite_the_message_and_add_context
    SolidErrorsTriage.configure do |c|
      c.normalize(lambda { |error|
        id = error.message[/\breq_[A-Za-z0-9]+/]
        next nil if id.nil?

        [ error.message.gsub(id, "req_[NORMALIZED]"), { request_id: id } ]
      })
    end

    error = RuntimeError.new("upstream failed (req_abc123)")
    context = SolidErrorsTriage.normalize(error, { user: 1 })

    assert_equal "upstream failed (req_[NORMALIZED])", error.message
    assert_equal({ user: 1, request_id: "req_abc123" }, context)
  end

  def test_a_normalizer_that_does_not_match_leaves_everything_alone
    SolidErrorsTriage.configure { |c| c.normalize(->(_error) { nil }) }

    error = RuntimeError.new("plain failure")
    assert_equal({ a: 1 }, SolidErrorsTriage.normalize(error, { a: 1 }))
    assert_equal "plain failure", error.message
  end
end
