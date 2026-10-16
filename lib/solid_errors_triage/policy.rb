# frozen_string_literal: true

module SolidErrorsTriage
  # Decides whether one occurrence is worth an email, and what its subject says.
  #
  # Pure on purpose: it takes counts, not records, so the rules can be tested
  # exhaustively without a database or the Solid Errors engine loaded.
  class Policy
    def initialize(config = SolidErrorsTriage.config)
      @config = config
    end

    # rank:         this occurrence's place among its error's, counting up to
    #               it rather than all of them (see Notifier)
    # recent_count: occurrences inside the rate window ending at this one
    #
    # Returns :milestone, :rate, or nil. :rate says the window is over the
    # threshold, not that it has just crossed it; RateGate keeps that to one
    # email.
    def trigger_for(rank:, recent_count: 0)
      return :milestone if milestone?(rank)
      return :rate if rate_exceeded?(recent_count)

      nil
    end

    # Roughly logarithmic on purpose: the 2nd occurrence tells you nothing the
    # 1st didn't, but the 100th says this is now systemic.
    def milestone?(rank)
      Array(@config.counts).include?(rank)
    end

    # At or over, not exactly on: as old occurrences leave the window a count
    # can sit on the threshold again and again, and equality would email each
    # time it did.
    def rate_exceeded?(recent_count)
      count = rate_count
      return false if count.nil? || rate_window.nil?

      recent_count >= count
    end

    def rate_count = (@config.rate_threshold || {})[:count]
    def rate_window = (@config.rate_threshold || {})[:window]

    # "3rd occurrence" and "resolved" are triaged very differently, and the
    # subject line is where that decision gets made. reason is what Solid
    # Errors passes (:created, :reopened, nil) or what Notifier sends.
    def subject_for(reason:, exception_class:, severity_emoji: nil, ordinal: nil)
      name = "#{severity_emoji} #{exception_class}".strip

      case reason
      when :resolved then "✅ RESOLVED: #{exception_class}"
      when :reopened then "#{name} (reopened)"
      when :milestone then "#{name} (#{ordinal} occurrence)"
      when :rate then "#{name} (rate spike)"
      else name
      end
    end
  end
end
