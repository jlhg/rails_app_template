# Logging

This application uses [`rails_semantic_logger`](https://github.com/reidmorrison/rails_semantic_logger) for all logging. In production every line emitted to STDOUT is a single JSON object so log aggregators can parse exception traces, Sidekiq output, and direct `Rails.logger.*` calls without special cases for non-JSON lines.

## Environment Matrix

| Environment | Formatter  | Sink           | Notes                                                                                                 |
|-------------|------------|----------------|-------------------------------------------------------------------------------------------------------|
| production  | `:json`    | STDOUT (only)  | Default file appender disabled. `request_id` and `ip` injected as named tags by Rack middleware.      |
| development | `:color`   | STDOUT         | Color multi-line output for human reading.                                                            |
| test        | `:default` | STDOUT         | Calls `SemanticLogger.sync!` so log writes happen synchronously and spec assertions observe them on the example thread. |

## Production JSON Schema

### Controller Request Summary

```json
{
  "host":        "server-7f9c",
  "application": "Rails",
  "timestamp":   "2026-05-20T10:14:22.345678Z",
  "level":       "info",
  "name":        "Rails",
  "message":     "Completed #show",
  "duration_ms": 23.4,
  "named_tags": {
    "request_id": "5b8b1a3a-2e7f-4f7e-9d11-...",
    "ip":         "10.0.0.42"
  },
  "payload": {
    "method":               "GET",
    "path":                 "/api/...",
    "format":               "JSON",
    "controller":           "SomeController",
    "action":               "show",
    "status":               200,
    "status_message":       "OK",
    "view_runtime":         1.2,
    "db_runtime":           4.5,
    "allocations":          18452,
    "queries_count":        7,
    "cached_queries_count": 2
  }
}
```

### Unhandled Exception

When a controller action raises an unhandled exception, two lines are emitted: a request summary line with `status: 500`, immediately followed by a structured exception line.

```json
{
  "level":      "fatal",
  "name":       "ActionDispatch::DebugExceptions",
  "message":    "StandardError: boom",
  "named_tags": { "request_id": "...", "ip": "..." },
  "exception": {
    "name":        "StandardError",
    "message":     "boom",
    "stack_trace": [
      "app/controllers/some_controller.rb:42:in 'block in show'",
      "..."
    ]
  }
}
```

If the exception has a cause chain, additional `cause` entries are nested inside the exception object.

### Sidekiq Job

```json
{
  "level":   "info",
  "name":    "Sidekiq",
  "message": "Job completed",
  "payload": { "job": { "class": "...", "jid": "...", "state": "completed" } }
}
```

## Named Tags

The `SemanticLoggerNamedTags` Rack middleware (`app/middleware/semantic_logger_named_tags.rb`, inserted after `ActionDispatch::RequestId`) attaches the following per-request tags to every log line emitted on the request thread.

| Tag          | Source                               | Notes                                                                                        |
|--------------|--------------------------------------|----------------------------------------------------------------------------------------------|
| `request_id` | `ActionDispatch::Request#request_id` | Always present.                                                                              |
| `ip`         | `ActionDispatch::Request#remote_ip`  | Always present.                                                                              |

## Attaching `user_id`

`user_id` is not attached by default because authentication is application-specific. To include it on every log line emitted during an authenticated action, declare an `around_action` in a controller concern that resolves your current user, and push the tag via `SemanticLogger.named_tagged`.

```ruby
# app/controllers/concerns/log_user_id.rb
module LogUserId
  extend ActiveSupport::Concern

  included do
    around_action :attach_user_id_log_tag
  end

  private

  def attach_user_id_log_tag(&block)
    # Adapt this to your auth mechanism. The guard avoids triggering a DB
    # lookup on endpoints that include this concern but never resolve a user
    # (e.g. public actions mixed with authenticated ones).
    return yield unless defined?(@current_user) && @current_user

    SemanticLogger.named_tagged(user_id: @current_user.id, &block)
  end
end
```

Include the concern in controllers that have already memoized `@current_user` via a `before_action` (Devise, JWT, custom session token, etc.). Log lines emitted outside the action body (the request summary emitted by the gem's subscriber after the action returns, plus lines from middleware below the controller) do not carry `user_id`; this matches how middleware-attached tags work and is acceptable for typical aggregator queries that filter on `request_id` first.

## Implementation References

- `config/environments/production.rb`: appender, formatter, semantic mode.
- `config/environments/development.rb` and `config/environments/test.rb`: formatter and sync overrides.
- `config/initializers/semantic_logger.rb`: middleware wiring.
- `app/middleware/semantic_logger_named_tags.rb`: per-request named-tag injection.
- `config/puma.rb`: `SemanticLogger.reopen` in `on_worker_boot` for forked Puma workers.
