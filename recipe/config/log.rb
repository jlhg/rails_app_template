# Logging Configuration
#
# rails_semantic_logger emits one JSON object per STDOUT line in production
# so log aggregators (ELK, Datadog, CloudWatch) parse exception traces,
# Sidekiq output, and direct Rails.logger.* calls uniformly.
#
# https://github.com/reidmorrison/rails_semantic_logger
#
# Per-request request_id and ip are attached as named tags by the
# SemanticLoggerNamedTags Rack middleware. See docs/logging.md for the
# production JSON schema and an example user_id around-action.

gem "rails_semantic_logger"

# Strip Rails 8.1 TaggedLogging defaults that would compete with the gem.
gsub_file "config/environments/production.rb",
          /^\s*# Log to STDOUT with the current request id as a default log tag\.\s*\n/, ""
gsub_file "config/environments/production.rb",
          /^\s*config\.log_tags\s*=.*\n/, ""
gsub_file "config/environments/production.rb",
          /^\s*config\.logger\s*=\s*ActiveSupport::TaggedLogging\.logger\(STDOUT\).*\n/, ""

environment <<~RUBY, env: "production"
  config.rails_semantic_logger.semantic = true

  # Declaring appenders replaces the gem's default file appender, so this
  # block is the complete destination list: STDOUT only, no log file.
  config.rails_semantic_logger.appenders do |appenders|
    appenders.add(io: $stdout, formatter: :json)
  end
RUBY

environment <<~RUBY, env: "development"
  # Declaring any appender opts out of the gem's automatic STDOUT appender,
  # so `rails server` needs an explicit add_server declaration to keep
  # printing to the terminal.
  config.rails_semantic_logger.appenders do |appenders|
    appenders.add(file_name: Rails.root.join("log/development.log").to_s, formatter: :color)
    appenders.add_server(io: $stdout, formatter: :color)
  end
  config.log_level = :debug
RUBY

environment <<~RUBY, env: "test"
  config.log_level = :warn
  config.rails_semantic_logger.appenders do |appenders|
    appenders.add(file_name: Rails.root.join("log/test.log").to_s, formatter: :default)
  end

  # Synchronous so spec log assertions run on the example thread.
  SemanticLogger.sync!
RUBY

after_bundle do
  # Lives under app/middleware/ so Zeitwerk's path-derived constant matches
  # the top-level SemanticLoggerNamedTags under production eager_load.
  copy_file from_files("app/middleware/semantic_logger_named_tags.rb"),
            "app/middleware/semantic_logger_named_tags.rb"

  copy_file from_files("config/initializers/semantic_logger.rb"),
            "config/initializers/semantic_logger.rb"
end
