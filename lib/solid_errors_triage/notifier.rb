# frozen_string_literal: true

module SolidErrorsTriage
  # Sends the emails Solid Errors does not: occurrence milestones, rate spikes and
  # resolutions. Driven by the events Solid Errors publishes once each change is
  # committed, and sent through Solid Errors' own mailer with a reason, which
  # SolidErrorsTriage.subject turns into the subject line.
  module Notifier
    def self.subscribe!
      ActiveSupport::Notifications.subscribe("occurrence_created.solid_errors") do |event|
        occurrence_created(event.payload[:occurrence])
      end

      ActiveSupport::Notifications.subscribe("error_resolved.solid_errors") do |event|
        error_resolved(event.payload[:error])
      end
    end

    def self.occurrence_created(occurrence)
      return unless SolidErrors.send_emails?
      # Every occurrence is already emailed; anything sent here would be a duplicate.
      return if SolidErrors.email_every_occurrence
      # Solid Errors emails the occurrence that creates or reopens an error itself.
      return if occurrence.opens_error

      error = occurrence.error
      # Counted up to this occurrence rather than in total: this runs after
      # commit, so two occurrences committed together would both count both and
      # neither would land on the milestone between them.
      up_to_here = error.occurrences.where(id: ..occurrence.id)
      window = policy.rate_window
      recent = window ? up_to_here.where(created_at: (occurrence.created_at - window)..).count : 0

      trigger = policy.trigger_for(rank: up_to_here.count, recent_count: recent)
      trigger = nil if trigger == :rate && !RateGate.claim(error.id, quiet: SolidErrorsTriage.config.rate_quiet)
      deliver(occurrence, trigger) if trigger
    end

    def self.error_resolved(error)
      return unless SolidErrors.send_emails? && SolidErrorsTriage.config.notify_on_resolved?

      # The mail template renders an occurrence, so an error pruned down to none
      # has nothing to show.
      occurrence = error.occurrences.order(:id).last
      deliver(occurrence, :resolved) if occurrence
    end

    # deliver_later, so reporting an error never blocks on SMTP. The consequence
    # worth knowing: error mail rides the queue, so an outage that takes the queue
    # down also takes down the mail telling you about it. The errors are still
    # recorded and the /errors page reads the database directly.
    def self.deliver(occurrence, reason)
      SolidErrors::ErrorMailer.error_occurred(occurrence, reason).deliver_later
    end

    def self.policy = SolidErrorsTriage.policy
  end
end
