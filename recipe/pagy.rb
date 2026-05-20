# Pagy Pagination Configuration Recipe
#
# The ultimate pagination ruby gem
# https://github.com/ddnexus/pagy

# Initializer below uses Pagy::DEFAULT[:items] and [:overflow], which only
# exist on pagy 9.x.
gem "pagy", "~> 9.4"

# Create pagy initializer after all generators complete.
# This ensures the gem is fully loaded before the initializer runs.
after_generators do
  initializer "pagy.rb", <<~CODE
    require "pagy/extras/overflow"

    Pagy::DEFAULT[:items] = 20
    Pagy::DEFAULT[:overflow] = :empty_page

    # Define min/max items per page for API validation.
    PAGY_ITEM_MIN = 5
    PAGY_ITEM_MAX = 100
  CODE
end
