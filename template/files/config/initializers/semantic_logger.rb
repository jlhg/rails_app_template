# Zeitwerk's main loader is activated after :load_config_initializers, so the
# middleware constant is not autoloadable here yet.
require Rails.root.join("app/middleware/semantic_logger_named_tags")

# After RequestId so request.request_id is set when this middleware runs.
Rails.application.config.middleware.insert_after(
  ActionDispatch::RequestId,
  SemanticLoggerNamedTags
)
