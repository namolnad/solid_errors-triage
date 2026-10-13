# frozen_string_literal: true

module SolidErrorsTriage
  # Decides whether one occurrence is worth an email, and why.
  #
  # Pure on purpose: it takes counts, not records, so the rules can be tested
  # exhaustively without a database or the Solid Errors engine loaded.
  class Policy
    def initialize(config = SolidErrorsTriage.config)
      @config = config
    end

    # occurrence_count: how many occurrences this error now has
    # recent_count:     occurrences inside the rate window
    #
    # Returns :milestone, :rate, or nil.
    def trigger_for(occurrence_count:, recent_count: 0)
      return :milestone if milestone?(occurrence_count)
      return :rate if rate_exceeded?(recent_count)

      nil
    end

    # Roughly logarithmic on purpose: the 2nd occurrence tells you nothing the
    # 1st didn't, but the 100th says this is now systemic.
    def milestone?(occurrence_count)
      Array(@config.counts).include?(occurrence_count)
    end

    # Equality, not >=, so crossing the window sends one email rather than one per
    # occurrence after it. A loop erroring 10,000 times sends one.
    def rate_exceeded?(recent_count)
      threshold = @config.rate_threshold || {}
      count = threshold[:count]
      window = threshold[:window]
      return false if count.nil? || window.nil?

      recent_count == count
    end

    def rate_window
      (@config.rate_threshold || {})[:window]
    end

    # "3rd occurrence" and "resolved" are triaged very differently, and the
    # subject line is where that decision gets made.
    def subject_for(trigger:, exception_class:, severity_emoji: nil, occurrence_ordinal: nil)
      case trigger
      when :resolved then "✅ RESOLVED: #{exception_class}"
      when :milestone then "#{severity_emoji} #{exception_class} (#{occurrence_ordinal} occurrence)"
      when :rate then "#{severity_emoji} #{exception_class} (rate spike)"
      else "#{severity_emoji} #{exception_class}"
      end.strip
    end
  end
end
