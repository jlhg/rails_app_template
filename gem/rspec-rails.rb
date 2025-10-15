gem "rspec-rails", group: [:development, :test]
run "bundle install"
run "rails g rspec:install"
environment <<~CODE
  config.generators do |g|
    g.test_framework :rspec,
                     fixtures: false,
                     view_specs: false,
                     helper_specs: false,
                     routing_specs: false,
                     controller_specs: false,
                     request_specs: true,
                     mailer_specs: true
    g.fixture_replacement :factory_bot, dir: "spec/factories"
  end
CODE
