# solid_errors_triage

Notification triage and retention for [Solid Errors](https://github.com/fractaledmind/solid_errors).

Solid Errors emails on every occurrence out of the box. For anything recurring
that trains you to filter the alerts — and a filtered alert is the same as no
alert. This fires on the transitions that carry information instead.

## Install

```ruby
gem "solid_errors_triage"
```

Adding the gem is the whole setup. Defaults are the rules below; override them in
`config/solid_errors.yml` (copy `config/solid_errors.example.yml` from this repo)
or in an initializer.

## What it changes

**Notification triggers.** Emails fire on occurrence milestones (1st, 10th, 100th,
1000th — roughly logarithmic, because the 2nd occurrence tells you nothing the 1st
didn't but the 100th says this is systemic), on a rate spike, and on resolve /
reopen. The rate rule fires *once* as the window is crossed rather than on every
occurrence after it, so a loop erroring 10,000 times sends one email.

**A source guard.** Rails sometimes reports errors with a String source (for
example `"application.action_dispatch"`), and the gem assumes a controller and
calls `action_name` on it. That raises inside the error reporter, which is the
worst possible place for an exception.

**Retention.** `SolidErrorsTriage::CleanupJob` prunes old *resolved* errors
nightly. Unresolved ones are never deleted at any age — an error nobody has looked
at is not an error nobody needs, and dropping it would make the errors page lie
about what is outstanding. Inline pruning is switched off, because doing it in two
places lands a multi-table delete inside the request that just errored.

```yaml
# config/recurring.yml
cleanup_solid_errors:
  class: SolidErrorsTriage::CleanupJob
  schedule: every day at 2am
```

**Development logs instead of storing.** Local exceptions are a firehose — every
typo in a view — and persisting them makes the errors page useless for the thing
it's for. Set `store_in_development = true` to exercise the page against real data.

## Fingerprint normalizers

An error message that embeds a per-request id fingerprints into one "error" per
API call, which buries a real outage under thousands of singletons. Which provider
does that is app-specific, so the rule is registered rather than baked in:

```ruby
# config/initializers/solid_errors_triage.rb
SolidErrorsTriage.configure do |config|
  config.normalize(lambda { |error|
    next nil unless defined?(Anthropic::Errors::APIError)
    next nil unless error.is_a?(Anthropic::Errors::APIError)

    id = error.message[/\breq_[A-Za-z0-9]+/]
    next nil if id.nil?

    # [replacement message, extra occurrence context]
    [ error.message.gsub(id, "req_[NORMALIZED]"), { anthropic_request_id: id } ]
  })
end
```

The id ends up in the occurrence context — still there to quote in a support
ticket — and out of the string the fingerprint is computed from.

## Configuration reference

```ruby
SolidErrorsTriage.configure do |config|
  config.counts = [ 1, 10, 100, 1_000 ]
  config.rate_threshold = { count: 30, window: 300 }  # seconds
  config.notify_on_resolved = true
  config.notify_on_reopened = true
  config.store_in_development = false
  config.prune_inline = false
end
```

Configuration Solid Errors itself reads earlier — `connects_to`, `destroy_after`,
`base_controller_class` — still belongs in `config/application.rb`, because the
engine reads it from its own initializer, which runs before `config/initializers/*`.

## A consequence worth knowing

Error mail is sent with `deliver_later`, so reporting an error never blocks on
SMTP. That means error mail rides the queue: an outage that takes the queue down
also takes down the emails telling you about it. The errors are still recorded —
the `/errors` page reads the database directly — they just won't arrive by mail.

## Tests

```bash
bundle exec rake test
```

The decision logic is a plain object taking counts rather than records, so the
rules are tested exhaustively without a database or the engine loaded.
