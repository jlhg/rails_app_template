# Image processing gem (recommended by Rails)
# Supports both libvips (faster, default) and ImageMagick
# libvips is 10x faster and uses 10% memory compared to ImageMagick
# https://github.com/janko/image_processing
gem "image_processing", "~> 1.2"

init_gem "active_storage_validations"

rails_command "active_storage:install"

# Configure ActiveStorage to use libvips (default in Rails 7+)
environment <<~CODE
  # ActiveStorage variant processor
  # :vips - Fast, low memory (recommended, requires libvips)
  # :mini_magick - Slower, higher memory (requires ImageMagick)
  config.active_storage.variant_processor = :vips
CODE

# NOTE: libvips must be installed in the system
# Dockerfile already includes libvips installation:
#   RUN apt-get install -y libvips (included in Debian slim)
