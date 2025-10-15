environment <<~CODE
  config.action_mailer.default_url_options = {
    host: ENV.fetch('MAILER_SERVER_HOST', 'localhost'),
    port: ENV.fetch('MAILER_SERVER_PORT', 3000).to_i,
    protocol: ENV.fetch('MAILER_SERVER_PROTOCOL', 'http')
  }
CODE
environment "config.action_mailer.raise_delivery_errors = true"
environment "config.action_mailer.delivery_method = :smtp"
environment <<~CODE
  config.action_mailer.smtp_settings = {
    address: ENV.fetch('MAILER_SMTP_ADDRESS', 'smtp.mailgun.org'),
    port: ENV.fetch('MAILER_SMTP_PORT', 587).to_i,
    domain: ENV.fetch('MAILER_SMTP_DOMAIN', 'mg.example.com'),
    authentication: ENV.fetch('MAILER_SMTP_AUTHENTICATION', 'plain').to_sym,
    enable_starttls_auto: ENV.fetch('MAILER_SMTP_ENABLE_STARTTLS_AUTO', 'true') == 'true',
    user_name: ENV.fetch('MAILER_SMTP_USER_NAME', 'postmaster@mg.example.com'),
    password: if ENV['MAILER_SMTP_PASSWORD_FILE'] && File.exist?(ENV['MAILER_SMTP_PASSWORD_FILE'])
      File.read(ENV['MAILER_SMTP_PASSWORD_FILE']).strip
    elsif ENV['MAILER_SMTP_PASSWORD']
      ENV['MAILER_SMTP_PASSWORD']
    else
      ''
    end
  }
CODE
