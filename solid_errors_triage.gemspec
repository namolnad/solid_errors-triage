# frozen_string_literal: true

require_relative "lib/solid_errors_triage/version"

Gem::Specification.new do |spec|
  spec.name          = "solid_errors_triage"
  spec.version       = SolidErrorsTriage::VERSION
  spec.authors       = [ "Dan Loman" ]
  spec.email         = [ "daniel.loman@gmail.com" ]

  spec.summary       = "Notification triage and retention for Solid Errors"
  spec.description   = <<~DESC.strip
    Replaces Solid Errors' email-on-every-occurrence with milestone, rate and
    lifecycle triggers, adds a nightly cleanup job for resolved errors, and
    guards the error reporter against non-controller sources.
  DESC
  spec.homepage      = "https://github.com/namolnad/solid_errors-triage"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.glob("lib/**/*") + %w[LICENSE README.md]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "railties", ">= 7.1"
  spec.add_dependency "solid_errors", ">= 0.5"
end
