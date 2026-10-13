# frozen_string_literal: true

module SolidErrorsTriage
  # Solid Errors' mail, with a subject that says which rule fired. Inherits the
  # templates, the occurrence link and the guard against a failing mailer
  # reporting -- and so emailing -- its own failure.
  class ErrorMailer < SolidErrors::ErrorMailer
    def triaged(occurrence, trigger:)
      @occurrence = occurrence
      @error = occurrence.error

      subject = SolidErrorsTriage.policy.subject_for(
        trigger: trigger,
        exception_class: @error.exception_class,
        severity_emoji: @error.severity_emoji,
        occurrence_ordinal: @error.occurrences.count.ordinalize
      )

      if SolidErrors.email_subject_prefix.present?
        subject = [ SolidErrors.email_subject_prefix, subject ].join(" ").squish
      end

      mail(
        subject: subject,
        from: SolidErrors.email_from,
        to: SolidErrors.email_to,
        template_path: "solid_errors/error_mailer",
        template_name: "error_occurred"
      )
    end
  end
end
