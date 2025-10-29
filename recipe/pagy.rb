# Pagy Pagination Configuration Recipe
#
# The ultimate pagination ruby gem
# https://github.com/ddnexus/pagy

gem "pagy"

initializer "pagy.rb", <<~CODE
  require "pagy/extras/overflow"

  Pagy::DEFAULT[:items] = 20
  Pagy::DEFAULT[:overflow] = :empty_page

  # Define min/max items per page for API validation
  PAGY_ITEM_MIN = 5
  PAGY_ITEM_MAX = 100
CODE
