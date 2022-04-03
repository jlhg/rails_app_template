# The ultimate pagination ruby gem. https://github.com/ddnexus/pagy
gem "pagy"
initializer "pagy.rb", <<-CODE
  Pagy::DEFAULT[:items] = 20
  Pagy::DEFAULT[:overflow] = :empty_page
CODE
