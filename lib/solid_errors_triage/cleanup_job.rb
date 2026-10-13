# frozen_string_literal: true

module SolidErrorsTriage
  # Prunes old *resolved* errors. Unresolved ones are never deleted at any age --
  # an error nobody has looked at is not an error nobody needs, and silently
  # dropping it would make the errors page lie about what is outstanding.
  #
  # Retention comes from destroy_resolved_after_days in config/solid_errors.yml
  # (or config.destroy_after, in seconds or as a Duration). Schedule it:
  #
  #   cleanup_solid_errors:
  #     class: SolidErrorsTriage::CleanupJob
  #     schedule: every day at 2am
  class CleanupJob < ActiveJob::Base
    queue_as :default

    def perform
      destroy_after = SolidErrorsTriage.config.destroy_after
      return if destroy_after.nil?

      cutoff = Time.current - destroy_after

      # Occurrences first: the errors delete below only catches rows left with
      # none, which is what stops a resolved error with recent occurrences from
      # disappearing early.
      occurrences = SolidErrors::Occurrence
        .where(error: SolidErrors::Error.resolved)
        .where(created_at: ...cutoff)
        .delete_all

      errors = SolidErrors::Error.resolved.where.missing(:occurrences).delete_all

      Rails.logger.info(
        "SolidErrorsTriage::CleanupJob: deleted #{occurrences} occurrences and #{errors} errors"
      )
    end
  end
end
