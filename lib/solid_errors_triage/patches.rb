# frozen_string_literal: true

module SolidErrorsTriage
  # Applied inside a to_prepare block by the railtie, so it survives reloading.
  module Patches
    def self.apply!
      patch_subscriber
      patch_occurrence
      patch_error
      patch_mailer
    end

    def self.policy = SolidErrorsTriage.policy

    def self.patch_subscriber
      SolidErrors::Subscriber.class_eval do
        alias_method :solid_errors_triage_original_report, :report

        def report(error, handled:, severity:, context:, source: nil)
          config = SolidErrorsTriage.config

          unless config.store_in_development? || !Rails.env.development?
            Rails.logger.error("🚨 [#{severity}] #{error.class}: #{error.message}")
            Rails.logger.error("   Context: #{context.inspect}") if context.present?
            Rails.logger.error(error.backtrace.first(10).join("\n   ")) if error.backtrace
            return
          end

          context = SolidErrorsTriage.normalize(error, context)

          # The gem calls source.action_name, so anything that isn't a controller
          # has to be dropped rather than passed through. Rails reports some
          # errors with a String source ("application.action_dispatch"), and the
          # resulting NoMethodError raises inside the error reporter -- the worst
          # possible place for an exception.
          if source.respond_to?(:action_name)
            solid_errors_triage_original_report(error, handled: handled, severity: severity, context: context, source: source)
          else
            solid_errors_triage_original_report(error, handled: handled, severity: severity, context: context)
          end
        end
      end
    end

    def self.patch_occurrence
      SolidErrors::Occurrence.class_eval do
        private
          def send_email
            policy = SolidErrorsTriage.policy
            window = policy.rate_window
            recent = window ? error.occurrences.where(created_at: window.seconds.ago..).count : 0

            trigger = policy.trigger_for(
              occurrence_count: error.occurrences.count,
              recent_count: recent
            )
            return if trigger.nil?

            # deliver_later, so reporting an error never blocks on SMTP. The
            # consequence worth knowing: error mail rides the queue, so an outage
            # that takes the queue down also takes down the mail telling you about
            # it. The errors are still recorded and the /errors page reads the
            # database directly.
            SolidErrors::ErrorMailer.error_occurred(self, trigger: trigger).deliver_later
          end

          def should_clear_resolved_errors? = SolidErrorsTriage.config.prune_inline?
      end
    end

    def self.patch_error
      SolidErrors::Error.class_eval do
        after_update_commit :solid_errors_triage_lifecycle_email, if: :saved_change_to_resolved_at?

        private
          def solid_errors_triage_lifecycle_email
            return unless SolidErrors.send_emails? && SolidErrors.email_to.present?

            trigger = SolidErrorsTriage.policy.lifecycle_trigger(
              was_resolved: resolved_at_before_last_save.present?,
              resolved: resolved?
            )
            return if trigger.nil?

            occurrence = occurrences.last || occurrences.new
            SolidErrors::ErrorMailer.error_occurred(occurrence, trigger: trigger).deliver_later
          end
      end
    end

    def self.patch_mailer
      SolidErrors::ErrorMailer.class_eval do
        def error_occurred(occurrence, trigger: nil)
          @occurrence = occurrence
          @error = occurrence.error
          @trigger = trigger

          subject = SolidErrorsTriage.policy.subject_for(
            trigger: trigger,
            exception_class: @error.exception_class,
            severity_emoji: @error.try(:severity_emoji),
            occurrence_ordinal: @error.occurrences.count.ordinalize
          )

          if SolidErrors.email_subject_prefix.present?
            subject = [ SolidErrors.email_subject_prefix, subject ].join(" ").squish
          end

          mail(subject: subject, from: SolidErrors.email_from, to: SolidErrors.email_to)
        end
      end
    end
  end
end
