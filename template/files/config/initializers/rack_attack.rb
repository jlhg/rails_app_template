# Rack::Attack Configuration
# Covers multiple common attack patterns with protection rules

# ============================================================================
# Cache Configuration
# ============================================================================

Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: ENV.fetch("REDIS_CACHE_URL", "redis://localhost:6379/1")
)

# ============================================================================
# Safelist (Allow List)
# ============================================================================

# Health check endpoint is unrestricted (Rails 8 built-in)
Rack::Attack.safelist("allow_health_check") do |req|
  req.path == "/up"
end

# Local development environment unrestricted (can be adjusted as needed)
Rack::Attack.safelist("allow_localhost") do |req|
  ["127.0.0.1", "::1"].include?(req.ip) if Rails.env.development?
end

# ============================================================================
# Blocklists (Block List)
# ============================================================================

# ----------------------------------------------------------------------------
# 1. Sensitive File Access
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_sensitive_files") do |req|
  sensitive_patterns = [
    # Environment variables and config files
    /\/\.env/i,                    # .env files
    /\/\.env\./i,                  # .env.local, .env.production
    /\/config\/\.env/i,            # config/.env
    /\/api\/\.env/i,               # api/.env

    # Git files
    /\/\.git/i, # .git/config
    /\/\.gitignore/i,
    /\/\.gitmodules/i,

    # Log files
    /\/logs?\//i,                  # /logs/, /log/
    /\.log$/i,                     # *.log
    /\/storage\/logs\//i,          # Laravel logs

    # Backup files
    /\/backup/i,                   # backup directory
    /\/dump/i,                     # dump files
    /\.sql$/i,                     # SQL backups
    /\.bak$/i,                     # .bak files
    /\.old$/i,                     # .old files
    /\.swp$/i,                     # Vim swap files
    /\.save$/i,

    # Keys and credentials
    /\/\.pem$/i,                   # SSL certificates
    /\/\.key$/i,                   # Private key files
    /\/\.crt$/i,                   # Certificates
    /\/\.cer$/i,
    /credentials/i,                # Credentials keyword
    /secrets?\//i,                 # secrets/ directory
    /\/\.secrets\//i,              # .secrets/ directory
    /\/\.ssh\//i,                  # SSH keys
    /id_rsa/i,                     # SSH private key

    # Cloud credentials
    /aws.*\.(js|json|yml|yaml)/i,  # AWS configuration
    /\/aws-export\.js/i,           # AWS export
    /\/\.aws\//i,                  # AWS directory
    /gcloud\.json/i,               # Google Cloud
    /firebase.*\.json/i,           # Firebase
    /service[-_]account\.json/i,   # Service account

    # Docker files
    /docker-compose/i,             # docker-compose files
    /compose\.ya?ml$/i,            # compose.yaml/yml
    /Dockerfile/i,                 # Dockerfile
    /\.dockerignore/i              # .dockerignore
  ]

  sensitive_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 2. PHP/WordPress Probes
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_php_wordpress") do |req|
  php_patterns = [
    # PHP files
    /\.php$/i,                     # Any .php files
    /phpinfo/i,                    # phpinfo.php
    /phpmyadmin/i,                 # phpMyAdmin
    /adminer\.php/i,               # Adminer

    # WordPress
    /wp-admin/i,                   # WordPress admin
    /wp-includes/i,                # WP includes
    /wp-content/i,                 # WP content
    /xmlrpc\.php/i,                # XML-RPC
    /wlwmanifest\.xml/i,           # WLW manifest
    /wp-config\.php/i,             # WP config
    /wordpress/i,                  # WordPress path

    # Other PHP frameworks/CMS
    /joomla/i,                     # Joomla
    /drupal/i,                     # Drupal
    /magento/i                     # Magento
  ]

  php_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 3. Admin Panel Probes
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_admin_probes") do |req|
  admin_patterns = [
    /\/admin\.php/i,
    /\/administrator/i,
    /\/manager/i,
    /\/console/i,
    /\/portal/i,
    /\/backend/i,
    /\/cpanel/i,
    /\/plesk/i,
    /\/webmail/i
  ]

  # Exception: Legitimate /a/admin or /api/admin routes in Rails app
  is_admin_path = admin_patterns.any? { |pattern| req.path =~ pattern }
  is_legitimate = req.path.start_with?("/a/admin") || req.path.start_with?("/api/admin")

  is_admin_path && !is_legitimate
end

# ----------------------------------------------------------------------------
# 4. Directory Traversal
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_directory_traversal") do |req|
  req.path.include?("../") ||
    req.path.include?("..\\") ||
    req.path.include?("%2e%2e") ||
    req.path.include?("..%2F") ||
    req.path.include?("..%5C")
end

# ----------------------------------------------------------------------------
# 5. SQL Injection / XSS
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_sql_injection_xss") do |req|
  query_string = req.query_string.to_s.downcase

  sql_xss_patterns = [
    "union select",
    "union all select",
    "base64_decode",
    "eval(",
    "<script",
    "javascript:",
    "onerror=",
    "onload=",
    "1=1",
    "' or '1'='1",
    '" or "1"="1'
  ]

  sql_xss_patterns.any? { |pattern| query_string.include?(pattern) }
end

# ----------------------------------------------------------------------------
# 6. Command Injection
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_command_injection") do |req|
  query_string = req.query_string.to_s

  command_patterns = [
    /\|.*cat/i,
    /\|.*ls/i,
    /\|.*wget/i,
    /\|.*curl/i,
    /;.*cat/i,
    /;.*ls/i,
    /`.*`/,
    /\$\(.*\)/
  ]

  command_patterns.any? { |pattern| query_string =~ pattern }
end

# ----------------------------------------------------------------------------
# 7. Laravel Specific Attacks
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_laravel_exploits") do |req|
  laravel_patterns = [
    /_ignition\/execute-solution/i, # Laravel Ignition RCE
    /_ignition\/health-check/i,
    /\/telescope/i,                   # Laravel Telescope
    /\/horizon/i,                     # Laravel Horizon
    /\/storage\/logs\//i,             # Laravel logs
    /\/\.env$/i,                      # Laravel .env
    /\/artisan$/i                     # Laravel artisan
  ]

  laravel_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 8. Symfony Profiler
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_symfony_profiler") do |req|
  symfony_patterns = [
    /_profiler/i,                     # Symfony Profiler
    /app_dev\.php/i,                  # Symfony dev mode
    /config\.php/i                    # Symfony config
  ]

  symfony_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 9. Spring Boot Actuator
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_spring_actuator") do |req|
  actuator_patterns = [
    /\/actuator/i, # Spring Boot Actuator
    /\/actuator\/env/i,
    /\/actuator\/heapdump/i,
    /\/actuator\/gateway\/routes/i,
    /\/actuator\/mappings/i
  ]

  actuator_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 10. Struts Vulnerabilities
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_struts_exploits") do |req|
  req.path =~ /\.action$/i || req.path =~ /\.do$/i
end

# ----------------------------------------------------------------------------
# 11. Nacos Configuration Center
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_nacos") do |req|
  req.path =~ /\/nacos\//i
end

# ----------------------------------------------------------------------------
# 12. File Manager Vulnerabilities
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_file_managers") do |req|
  file_manager_patterns = [
    /\/kcfinder\//i,                  # KCFinder
    /\/elfinder\//i,                  # elFinder
    /\/filemanager\//i,               # Generic file managers
    /\/tinymce\//i                    # TinyMCE
  ]

  file_manager_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 13. CI/CD Configuration File Probes
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_cicd_configs") do |req|
  cicd_patterns = [
    /\/\.gitlab-ci\.yml$/i,           # GitLab CI
    /\/\.travis\.yml$/i,              # Travis CI
    /\/\.circleci\//i,                # CircleCI
    /\/\.github\/workflows\//i,       # GitHub Actions
    /\/\.drone\.yml$/i,               # Drone CI
    /\/jenkins/i,                     # Jenkins
    /\/bamboo/i,                      # Bamboo
    /\/teamcity/i                     # TeamCity
  ]

  cicd_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 14. IDE Configuration File Probes
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_ide_configs") do |req|
  ide_patterns = [
    /\/\.vscode\//i,                  # VSCode
    /\/\.idea\//i,                    # IntelliJ IDEA
    /\/\.settings\//i,                # Eclipse
    /\/\.project$/i,                  # Eclipse project
    /\/\.classpath$/i                 # Eclipse classpath
  ]

  ide_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 15. Node.js Configuration Files
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_nodejs_configs") do |req|
  nodejs_patterns = [
    /\/package\.json$/i,
    /\/package-lock\.json$/i,
    /\/yarn\.lock$/i,
    /\/\.npmrc$/i,
    /\/\.yarnrc$/i,
    /\/node_modules\//i
  ]

  nodejs_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 16. Search Engine Probes
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_search_engines") do |req|
  search_patterns = [
    /\/solr\//i,                      # Apache Solr
    /\/elasticsearch\//i,             # Elasticsearch
    /\/kibana\//i,                    # Kibana
    /\/_cat\//i,                      # Elasticsearch _cat API
    /\/_search$/i                     # Elasticsearch search
  ]

  search_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 17. System File Access
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_system_files") do |req|
  system_patterns = [
    /\/etc\/passwd/i,
    /\/etc\/shadow/i,
    /\/etc\/hosts/i,
    /\/proc\/self/i,
    /\/proc\/cpuinfo/i,
    /\/windows\/win\.ini/i,
    /\/windows\/system\.ini/i
  ]

  system_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 18. Application Configuration Files
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_app_configs") do |req|
  config_patterns = [
    /\/config\.json$/i,
    /\/config\.yml$/i,
    /\/config\.yaml$/i,
    /\/config\.xml$/i,
    /\/application\.properties$/i,
    /\/application\.yml$/i,
    /\/appsettings\.json$/i,
    /\/web\.config$/i,
    /\/settings\.json$/i
  ]

  config_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 19. Test/Debug Paths
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_test_debug_paths") do |req|
  test_patterns = [
    /\/debug/i,
    /\/demo/i,
    /\/dev\//i,
    /\/test/i,
    /\/staging/i,
    /\/phpunit/i,
    /\/vendor\/phpunit/i
  ]

  # Exception: Rails app may have legitimate /api/v1/test routes
  is_test_path = test_patterns.any? { |pattern| req.path =~ pattern }
  is_legitimate = req.path.start_with?("/api/") && req.path.include?("/test")

  is_test_path && !is_legitimate
end

# ----------------------------------------------------------------------------
# 20. Database Files
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_database_files") do |req|
  db_patterns = [
    /database\.ya?ml$/i,
    /\.sqlite$/i,
    /\.sqlite3$/i,
    /\.db$/i,
    /\.mdb$/i
  ]

  db_patterns.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# 21. Monitoring Systems
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_monitoring_systems") do |req|
  monitoring_patterns = [
    /\/nagios\//i,
    /\/zabbix\//i,
    /\/prometheus\//i,
    /\/grafana\//i,
    /\/metrics$/i
  ]

  # Exception: If app has legitimate /metrics endpoint
  is_monitoring = monitoring_patterns.any? { |pattern| req.path =~ pattern }
  is_legitimate = req.path == "/metrics" && ENV["ENABLE_METRICS"] == "true"

  is_monitoring && !is_legitimate
end

# ----------------------------------------------------------------------------
# 22. Known Scanner Tool User-Agents
# ----------------------------------------------------------------------------

Rack::Attack.blocklist("block_scanner_user_agents") do |req|
  user_agent = req.user_agent.to_s.downcase

  scanner_patterns = [
    "sqlmap",
    "nikto",
    "nmap",
    "masscan",
    "acunetix",
    "nessus",
    "openvas",
    "scanner",
    "exploit",
    "metasploit",
    "burpsuite",
    "dirbuster",
    "gobuster",
    "wpscan",
    "nuclei"
  ]

  # Exclude legitimate crawlers
  legitimate_bots = ["googlebot", "bingbot", "slackbot", "twitterbot", "facebookexternalhit"]
  is_legitimate = legitimate_bots.any? { |bot| user_agent.include?(bot) }

  !is_legitimate && scanner_patterns.any? { |pattern| user_agent.include?(pattern) }
end

# ----------------------------------------------------------------------------
# 23. Wildcard Path Attacks - Special Handling
# ----------------------------------------------------------------------------

# Note: /* paths may be legitimate API wildcard requests
# Recommend handling at Cloudflare WAF level, or adjust based on actual needs

# Rack::Attack.blocklist('block_wildcard_paths') do |req|
#   # Only block HEAD method /* requests
#   req.request_method == 'HEAD' && req.path == '/*'
# end

# ============================================================================
# Throttling (Rate Limiting)
# ============================================================================

# ----------------------------------------------------------------------------
# Limit excessive 404 requests (scanner characteristic)
# ----------------------------------------------------------------------------

Rack::Attack.throttle("limit_404_scanning", limit: 10, period: 60.seconds) do |req|
  # Only set discriminator here, actual 404 check needs after_action handling
  req.ip if req.path =~ /\/(config|\.env|backup|logs|\.git|api|admin|debug)/
end

# ----------------------------------------------------------------------------
# Limit repeated requests to sensitive paths
# ----------------------------------------------------------------------------

Rack::Attack.throttle("limit_sensitive_path_requests", limit: 5, period: 60.seconds) do |req|
  sensitive_paths = [
    /\/\.env/i,
    /\/\.git/i,
    /\/config\//i,
    /\/backup/i,
    /\/admin/i
  ]

  req.ip if sensitive_paths.any? { |pattern| req.path =~ pattern }
end

# ----------------------------------------------------------------------------
# Global Rate Limiting (DDoS Prevention)
# ----------------------------------------------------------------------------

Rack::Attack.throttle("limit_requests_per_ip", limit: 300, period: 5.minutes) do |req|
  # Exclude health check endpoint
  req.ip unless req.path == "/up"
end

# ============================================================================
# Custom Responses
# ============================================================================

# Blocklist response (403 Forbidden)
Rack::Attack.blocklisted_responder = lambda do |_env|
  [
    403,
    { "Content-Type" => "application/json" },
    [{ error: "Forbidden", message: "Access denied" }.to_json]
  ]
end

# Throttle response (429 Too Many Requests)
Rack::Attack.throttled_responder = lambda do |env|
  match_data = env["rack.attack.match_data"]
  retry_after = match_data[:period]

  [
    429,
    {
      "Content-Type" => "application/json",
      "Retry-After"  => retry_after.to_s
    },
    [{
      error:       "Too Many Requests",
      message:     "Rate limit exceeded. Please try again later.",
      retry_after: retry_after
    }.to_json]
  ]
end

# ============================================================================
# Logging
# ============================================================================

ActiveSupport::Notifications.subscribe("rack.attack") do |_name, _start, _finish, _request_id, payload|
  req = payload[:request]

  case req.env["rack.attack.match_type"]
  when :blocklist
    Rails.logger.warn(
      "[Rack::Attack] Blocked: #{req.env['rack.attack.matched']} | " \
      "IP: #{req.ip} | " \
      "Path: #{req.path} | " \
      "User-Agent: #{req.user_agent}"
    )
  when :throttle
    Rails.logger.warn(
      "[Rack::Attack] Throttled: #{req.env['rack.attack.matched']} | " \
      "IP: #{req.ip} | " \
      "Path: #{req.path}"
    )
  end
end
