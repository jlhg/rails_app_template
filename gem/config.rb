# Easiest way to add multi-environment yaml settings to Rails,
# Sinatra, Pandrino and other ruby projects.
# https://github.com/railsconfig/config
gem "config", "4.2.1", github: "rubyconfig/config"
run "bundle install"
run "rails g config:install"
inside("config/initializers") do
  run("mv config.rb _config.rb")
end
