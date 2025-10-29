# Alba - Fast JSON Serializer
# https://github.com/okuramasafumi/alba
#
# Alba is a simple, modern, and fast JSON serializer for Ruby.
# Faster than ActiveModel::Serializers and Jbuilder.
#
# Features:
# - High performance (faster than AMS and Jbuilder)
# - Simple DSL with explicit attribute declarations
# - Supports associations, conditional attributes, and custom transformations
# - No magic, easy to understand and debug
#
# Example:
#   class UserResource
#     include Alba::Resource
#     attributes :id, :name, :email
#     attribute :created_at do |user|
#       user.created_at.iso8601
#     end
#   end

gem "alba"
