# Pagy Pagination Configuration Recipe
#
# The ultimate pagination ruby gem
# https://github.com/ddnexus/pagy

gem "pagy", "~> 43.6"

# Create pagy initializer after all generators complete.
# This ensures the gem is fully loaded before the initializer runs.
after_generators do
  initializer "pagy.rb", <<~CODE
    Pagy::OPTIONS[:limit] = 20

    # Setting :max_limit opts the app into client-controlled page size:
    # requests may pass ?limit=N, capped at this value.
    Pagy::OPTIONS[:max_limit] = 100

    Pagy::OPTIONS.freeze
  CODE
end
