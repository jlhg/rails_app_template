init_gem "rspec-rails"
init_gem "shoulda-matchers"
init_gem "factory_bot_rails"
init_gem "mock_redis"
init_gem "prosopite"

# Override .rspec configuration to enable deprecation warnings
copy_file File.join(files_path, ".rspec"), ".rspec", force: true

start = 8
lines = File.readlines("spec/rails_helper.rb")

# Sort support files to ensure proper loading order
# bcrypt and seeds must be loaded early
support_files = Dir[File.join(recipe_path, "rspec/support/*")].sort_by do |f|
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
