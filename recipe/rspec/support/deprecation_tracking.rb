# RSpec Deprecation Warning Tracking
#
# This configuration captures and reports Ruby and Rails deprecation warnings
# during test execution.
#
# Features:
# - Collects all deprecation warnings during test run
# - Displays warnings in a formatted report after all specs complete
# - Groups warnings by type for easier analysis
# - Shows file location where deprecation occurred
#
# Environment Variables:
# - FAIL_ON_DEPRECATIONS=true - Fail test suite if any deprecations found
# - DEPRECATION_WARNINGS_FILE=<path> - Save warnings to file for CI/CD integration

RSpec.configure do |config|
  # Enable Ruby deprecation warnings
  config.before(:suite) do
    # Store original verbose setting
    @original_verbose = $VERBOSE
    $VERBOSE = true

    # Set Ruby to show deprecated warnings
    Warning[:deprecated] = true if Warning.respond_to?(:[]=)

    # Capture all warnings
    @deprecation_warnings = []
    @warning_buffer = StringIO.new

    # Override Warning.warn to capture deprecation warnings
    Warning.singleton_class.prepend(Module.new do
      def warn(message)
        if message.include?("deprecated") || message.include?("deprecation")
          Thread.current[:deprecation_warnings] ||= []
          Thread.current[:deprecation_warnings] << {
            message:   message,
            location:  caller(2..2).first,
            timestamp: Time.now
          }
        end
        super
      end
    end)

    # Capture Rails deprecation warnings
    if defined?(ActiveSupport::Deprecation)
      ActiveSupport::Deprecation.behavior = lambda do |message, callstack, _deprecation_horizon, _gem_name|
        Thread.current[:deprecation_warnings] ||= []
        Thread.current[:deprecation_warnings] << {
          message:   message,
          location:  callstack.first,
          timestamp: Time.now,
          type:      "Rails"
        }
      end
    end
  end

  config.after(:suite) do
    # Restore original verbose setting
    $VERBOSE = @original_verbose

    # Collect all warnings from all threads
    all_thread_warnings = Thread.list.flat_map do |thread|
      thread[:deprecation_warnings] || []
    end
    all_warnings = all_thread_warnings.uniq { |w| [w[:message], w[:location]] }

    # Display warnings if any were found
    if all_warnings.any?
      puts "\n"
      puts "=" * 80
      puts "DEPRECATION WARNINGS DETECTED (#{all_warnings.count})"
      puts "=" * 80

      # Group warnings by message
      warnings_by_message = all_warnings.group_by { |w| w[:message] }

      warnings_by_message.each_with_index do |(message, occurrences), index|
        puts "\n#{index + 1}. #{message.strip}"
        puts "   Occurrences: #{occurrences.count}"
        puts "   First location: #{occurrences.first[:location]}"

        # Show up to 3 unique locations
        unique_locations = occurrences.map { |w| w[:location] }.uniq.take(3)
        if unique_locations.count > 1
          puts "   Other locations:"
          unique_locations[1..].each do |location|
            puts "     - #{location}"
          end
        end
      end

      puts "\n" + ("=" * 80)
      puts "SUMMARY: #{all_warnings.count} deprecation warning(s) found"
      puts "=" * 80
      puts "\n"

      # Save to file if requested
      if ENV["DEPRECATION_WARNINGS_FILE"]
        File.open(ENV["DEPRECATION_WARNINGS_FILE"], "w") do |f|
          f.puts "Deprecation Warnings Report"
          f.puts "Generated: #{Time.now}"
          f.puts "Total: #{all_warnings.count}"
          f.puts "\n"

          warnings_by_message.each_with_index do |(message, occurrences), index|
            f.puts "#{index + 1}. #{message.strip}"
            f.puts "   Occurrences: #{occurrences.count}"
            f.puts "   Locations:"
            occurrences.map { |w| w[:location] }.uniq.each do |location|
              f.puts "     - #{location}"
            end
            f.puts "\n"
          end
        end
        puts "Deprecation warnings saved to: #{ENV['DEPRECATION_WARNINGS_FILE']}"
      end

      # Fail if requested
      if ENV["FAIL_ON_DEPRECATIONS"] == "true"
        raise "Test suite failed due to #{all_warnings.count} deprecation warning(s)"
      end
    end
  end
end
