require "rails_helper"

RSpec.describe "Security: Path Scanning Protection", type: :request do
  # Tests based on real attack pattern analysis
  # Covers multiple common attack patterns

  describe "Rack::Attack integration" do
    it "is properly configured" do
      expect(Rack::Attack.cache.store).to be_present
    end
  end

  # ============================================================================
  # 1. Sensitive File Access
  # ============================================================================

  describe "sensitive file access" do
    context "environment files" do
      it "blocks .env file" do
        get "/.env"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks .env.local file" do
        get "/.env.local"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks api/.env file" do
        get "/api/.env"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks config/.env file" do
        get "/config/.env"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "git files" do
      it "blocks .git/config" do
        get "/.git/config"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks .gitignore" do
        get "/.gitignore"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "log files" do
      it "blocks log directory access" do
        get "/logs/production.log"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks .log files" do
        get "/application.log"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks Laravel logs" do
        get "/storage/logs/laravel.log"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "backup files" do
      it "blocks backup directory" do
        get "/backup/database.sql"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks .sql files" do
        get "/dump.sql"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks .bak files" do
        get "/config.bak"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "credentials and keys" do
      it "blocks .pem files" do
        get "/certificate.pem"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks .key files" do
        get "/private.key"
        expect(response).to have_http_status(:forbidden)
      end

      it 'blocks paths containing "credentials"' do
        get "/credentials.json"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks .secrets directory" do
        get "/.secrets/database_password"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks SSH keys" do
        get "/.ssh/id_rsa"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "cloud credentials" do
      it "blocks aws-export.js" do
        get "/aws-export.js"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks AWS config files" do
        get "/aws-config.json"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks gcloud.json" do
        get "/gcloud.json"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks firebase config" do
        get "/firebase-config.json"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "docker files" do
      it "blocks docker-compose files" do
        get "/docker-compose.yaml"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks compose.yaml" do
        get "/compose.yaml"
        expect(response).to have_http_status(:forbidden)
      end

      it "blocks Dockerfile" do
        get "/Dockerfile"
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ============================================================================
  # 2. PHP/WordPress Probes
  # ============================================================================

  describe "PHP and WordPress probes" do
    it "blocks phpinfo.php" do
      get "/phpinfo.php"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks phpinfo without extension" do
      get "/phpinfo"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks wp-admin" do
      get "/wp-admin/index.php"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks wp-includes" do
      get "/wp-includes/wlwmanifest.xml"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks xmlrpc.php" do
      get "/xmlrpc.php"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks phpmyadmin" do
      get "/phpmyadmin/"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks any .php file" do
      get "/test.php"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 3. Directory Traversal
  # ============================================================================

  describe "directory traversal attacks" do
    it "blocks ../ patterns" do
      get "/api/v1/users/../../../.env"
      expect(response).to have_http_status(:forbidden)
    end

    it 'blocks ..\\ patterns (Windows)' do
      get '/api\\..\\..\\config'
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks URL-encoded ../ patterns" do
      get "/api%2F..%2F..%2F.env"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 4. SQL Injection / XSS
  # ============================================================================

  describe "SQL injection and XSS attempts" do
    it "blocks SQL injection in query string" do
      get "/api/users?id=1 union select * from users"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks XSS script tags in query string" do
      get "/api/search?q=<script>alert(1)</script>"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks base64_decode in query string" do
      get "/api/data?code=base64_decode(evil)"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 5. Laravel Specific Attacks
  # ============================================================================

  describe "Laravel framework exploits" do
    it "blocks Laravel Ignition RCE" do
      get "/_ignition/execute-solution"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks Laravel Telescope" do
      get "/telescope/requests"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks Laravel Horizon" do
      get "/horizon/api/stats"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks Laravel artisan" do
      get "/artisan"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 6. Symfony Profiler
  # ============================================================================

  describe "Symfony framework exploits" do
    it "blocks Symfony Profiler" do
      get "/_profiler/phpinfo"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks Symfony dev mode" do
      get "/app_dev.php"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 7. Spring Boot Actuator
  # ============================================================================

  describe "Spring Boot exploits" do
    it "blocks actuator/env endpoint" do
      get "/actuator/env"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks actuator/heapdump" do
      get "/actuator/heapdump"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks actuator/gateway" do
      get "/actuator/gateway/routes"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 8. Struts Vulnerabilities
  # ============================================================================

  describe "Struts vulnerabilities" do
    it "blocks .action files" do
      get "/user.action"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks .do files" do
      get "/login.do"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 9. CI/CD Configuration File Probes
  # ============================================================================

  describe "CI/CD configuration files" do
    it "blocks .gitlab-ci.yml" do
      get "/.gitlab-ci.yml"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks .travis.yml" do
      get "/.travis.yml"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks CircleCI config" do
      get "/.circleci/config.yml"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks GitHub Actions workflows" do
      get "/.github/workflows/ci.yml"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 10. IDE Configuration File Probes
  # ============================================================================

  describe "IDE configuration files" do
    it "blocks VSCode settings" do
      get "/.vscode/settings.json"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks IntelliJ IDEA config" do
      get "/.idea/.env"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks Eclipse settings" do
      get "/.settings/org.eclipse.core.resources.prefs"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 11. Node.js Configuration Files
  # ============================================================================

  describe "Node.js configuration files" do
    it "blocks package.json" do
      get "/package.json"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks package-lock.json" do
      get "/package-lock.json"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks .npmrc" do
      get "/.npmrc"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks node_modules directory" do
      get "/node_modules/express/package.json"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 12. Search Engine Probes
  # ============================================================================

  describe "search engine probes" do
    it "blocks Apache Solr" do
      get "/solr/admin/cores"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks Elasticsearch" do
      get "/elasticsearch/_cat/indices"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks Kibana" do
      get "/kibana/api/status"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 13. System File Access
  # ============================================================================

  describe "system file access" do
    it "blocks /etc/passwd" do
      get "/etc/passwd"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks /etc/shadow" do
      get "/etc/shadow"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks /proc/self" do
      get "/proc/self/environ"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks Windows system files" do
      get "/windows/win.ini"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 14. Application Configuration Files
  # ============================================================================

  describe "application configuration files" do
    it "blocks config.json" do
      get "/config.json"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks application.properties" do
      get "/application.properties"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks appsettings.json" do
      get "/appsettings.json"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks web.config" do
      get "/web.config"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 15. Database Files
  # ============================================================================

  describe "database files" do
    it "blocks database.yml" do
      get "/database.yml"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks SQLite files" do
      get "/db.sqlite3"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 16. File Manager Vulnerabilities
  # ============================================================================

  describe "file manager vulnerabilities" do
    it "blocks KCFinder" do
      get "/kcfinder/upload.php"
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks elFinder" do
      get "/elfinder/connector.php"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================================================
  # 17. Known Scanner Tool User-Agents
  # ============================================================================

  describe "scanner user agents" do
    let(:headers) { { "HTTP_USER_AGENT" => user_agent } }

    context "blocks known scanners" do
      ["sqlmap", "nikto", "nmap", "masscan", "acunetix"].each do |scanner|
        it "blocks #{scanner}" do
          get "/api/users", headers: { "HTTP_USER_AGENT" => scanner }
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context "allows legitimate bots" do
      it "allows Googlebot" do
        get "/api/users", headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; Googlebot/2.1)" }
        expect(response).not_to have_http_status(:forbidden)
      end
    end
  end

  # ============================================================================
  # Positive Tests - Legitimate Requests Should Not Be Blocked
  # ============================================================================

  describe "legitimate requests" do
    it "allows health check endpoint" do
      get "/up"
      expect(response).not_to have_http_status(:forbidden)
    end

    it "allows API requests" do
      # Assumes /api/v1/users route exists
      # Adjust based on actual project routes
      get "/api/v1/users"
      expect(response).not_to have_http_status(:forbidden)
    end

    it "allows normal paths" do
      get "/"
      expect(response).not_to have_http_status(:forbidden)
    end
  end
end
