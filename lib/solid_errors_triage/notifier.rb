# frozen_string_literal: true

module SolidErrorsTriage
  # Sends the emails Solid Errors does not: occurrence milestones, rate spikes and
  # resolutions. Driven by the events Solid Errors publishes once each change is
  # committed.
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
      window = policy.rate_window
      recent = window ? error.occurrences.where(created_at: window.seconds.ago..).count : 0

      trigger = policy.trigger_for(
        occurrence_count: error.occurrences.count,
        recent_count: recent
      )
      deliver(occurrence, trigger) if trigger
    end

    def self.error_resolved(error)
      return unless SolidErrors.send_emails? && SolidErrorsTriage.config.notify_on_resolved?

      # The mail template renders an occurrence, so an error pruned down to none
      # has nothing to show.
      occurrence = error.occurrences.order(:created_at).last
      deliver(occurrence, :resolved) if occurrence
    end

    # deliver_later, so reporting an error never blocks on SMTP. The consequence
    # worth knowing: error mail rides the queue, so an outage that takes the queue
    # down also takes down the mail telling you about it. The errors are still
    # recorded and the /errors page reads the database directly.
    def self.deliver(occurrence, trigger)
      SolidErrorsTriage::ErrorMailer.triaged(occurrence, trigger: trigger).deliver_later
    end

    def self.policy = SolidErrorsTriage.policy
  end
end
