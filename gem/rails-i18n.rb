require "net/http"
require "uri"

# Repository for collecting Locale data for Ruby on Rails I18n as well
# as other interesting, Rails related I18n stuff http://rails-i18n.org
gem "rails-i18n"

# I18n configuration
environment "config.i18n.default_locale = :en"
environment "config.i18n.available_locales = [:en, :\"zh-TW\"]"
environment "config.i18n.fallbacks = [:en, :\"zh-TW\"]"

# Load locale enforcement middleware
initializer "locale.rb", <<-CODE
  # Enforce locale from Accept-Language header or default
  class LocaleMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      locale = extract_locale(env) || I18n.default_locale
      I18n.with_locale(locale) { @app.call(env) }
    end

    private

    def extract_locale(env)
      accept_language = env["HTTP_ACCEPT_LANGUAGE"]
      return nil unless accept_language

      # Parse Accept-Language header
      accepted = accept_language.split(",").map do |lang|
        locale, quality = lang.split(";q=")
        quality = quality ? quality.to_f : 1.0
        [locale.strip.split("-").first.to_sym, quality]
      end.sort_by { |_, quality| -quality }

      # Find first available locale
      accepted.find { |locale, _| I18n.available_locales.include?(locale) }&.first
    end
  end

  Rails.application.config.middleware.use LocaleMiddleware
CODE

# Download zh-TW locale file using Net::HTTP (safer than open-uri)
# open-uri has security vulnerabilities (CVE-2025-61594, RCE risks)
# Reference: https://www.ruby-lang.org/en/news/2025/10/07/uri-cve-2025-61594/
locale_url = URI.parse("https://github.com/svenfuchs/rails-i18n/raw/master/rails/locale/zh-TW.yml")
locale_content = Net::HTTP.get_response(locale_url)
if locale_content.is_a?(Net::HTTPSuccess)
  file "config/locales/zh-TW.yml", locale_content.body
else
  say "Warning: Failed to download zh-TW locale file (HTTP #{locale_content.code})"
  say "   You can manually download it later from:"
  say "   https://github.com/svenfuchs/rails-i18n/raw/master/rails/locale/zh-TW.yml"
end
