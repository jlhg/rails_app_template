gem "rspec-rails"
gem "shoulda-matchers"
gem "factory_bot_rails"
gem "faker"
gem "mock_redis"
gem "prosopite"

# Generate RSpec installation
generate "rspec:install"

# Override .rspec configuration to enable deprecation warnings
copy_file from_files(".rspec"), ".rspec", force: true

start = 8
lines = File.readlines("spec/rails_helper.rb")

# Sort support files to ensure proper loading order
# bcrypt and seeds must be loaded early
support_files = Dir[from_files("spec/support/*")].sort_by do |f|
  name = File.basename(f, ".rb")
  case name
  when "bcrypt" then "0_bcrypt"
  when "seeds" then "1_seeds"
  else name
  end
end

support_files.each do |f|
  lib_name = File.basename(f, ".rb")
  file "spec/support/#{lib_name}.rb", File.read(f)
  lines.insert(start, "require \"support/#{lib_name}\"\n")
  start += 1
end

File.open("spec/rails_helper.rb", "w") do |f|
  f.write(lines.join)
  f.flush
end
