# frozen_string_literal: true

module SolidErrorsTriage
  # Stands in for Solid Errors' own error subscriber, running the registered
  # normalizers before the error is fingerprinted. Installed only when there are
  # normalizers, so an app without any reports straight to Solid Errors.
  class NormalizingSubscriber
    def self.install!
      return if SolidErrorsTriage.config.normalizers.empty?
      return unless defined?(SolidErrors::Subscriber) && SolidErrors.enabled

      Rails.error.unsubscribe(SolidErrors::Subscriber)
      Rails.error.subscribe(new(SolidErrors::Subscriber.new))
    end

    def initialize(subscriber)
      @subscriber = subscriber
    end

    def report(error, context:, **options)
      @subscriber.report(error, context: SolidErrorsTriage.normalize(error, context), **options)
    end
  end
end
