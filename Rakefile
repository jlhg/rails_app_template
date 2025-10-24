# frozen_string_literal: true

desc "Check code style with RuboCop (use: rubocop, rubocop[fix], rubocop:app, rubocop:template)"
task :rubocop, [:mode] do |_t, args|
  mode = args[:mode]
  fix_flag = mode == "fix" ? "-A" : ""

  puts "🔍 Checking rails_app_template files..."
  sh "rubocop #{fix_flag}"

  puts "\n🔍 Checking template files..."
  sh "rubocop #{fix_flag} -c template/files/.rubocop.yml template/files/ recipe/rspec/support/"

  puts "\n✅ All checks complete!"
end

namespace :rubocop do
  desc "Check rails_app_template files only"
  task :app, [:mode] do |_t, args|
    mode = args[:mode]
    fix_flag = mode == "fix" ? "-A" : ""

    puts "🔍 Checking rails_app_template files..."
    sh "rubocop #{fix_flag}"
  end

  desc "Check template files only"
  task :template, [:mode] do |_t, args|
    mode = args[:mode]
    fix_flag = mode == "fix" ? "-A" : ""

    puts "🔍 Checking template files..."
    sh "rubocop #{fix_flag} -c template/files/.rubocop.yml template/files/ recipe/rspec/support/"
  end
end

desc "Show available rake tasks"
task :help do
  puts <<~HELP

    📋 Available Rake Tasks:

    Code Style Checking (RuboCop):
      rake rubocop              # Check all files (app + template)
      rake rubocop[fix]         # Auto-correct all files
      rake rubocop:app          # Check rails_app_template files only
      rake rubocop:app[fix]     # Auto-correct rails_app_template files
      rake rubocop:template     # Check template files only
      rake rubocop:template[fix] # Auto-correct template files

    Other:
      rake help                 # Show this help message
      rake -T                   # List all tasks

  HELP
end

task default: :help
