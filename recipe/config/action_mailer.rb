environment "config.action_mailer.raise_delivery_errors = true"
environment "config.action_mailer.delivery_method = :smtp"
environment <<~CODE
  config.action_mailer.default_url_options = {
    host:     AppConfig.instance.mailer_server_host,
    port:     AppConfig.instance.mailer_server_port,
    protocol: AppConfig.instance.mailer_server_protocol
  }
CODE
environment <<~CODE
  config.action_mailer.smtp_settings = {
    address:              AppConfig.instance.mailer_smtp_address,
    port:                 AppConfig.instance.mailer_smtp_port,
    domain:               AppConfig.instance.mailer_smtp_domain,
    authentication:       AppConfig.instance.mailer_smtp_authentication,
    enable_starttls_auto: AppConfig.instance.mailer_smtp_enable_starttls_auto,
    user_name:            AppConfig.instance.mailer_smtp_user_name,
    password:             AppConfig.instance.mailer_smtp_password
  }
CODE
