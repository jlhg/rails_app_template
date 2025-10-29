# Pundit - Authorization Library
# https://github.com/varvet/pundit
#
# Pundit provides a set of helpers for building authorization policies.
# Simple, object-oriented approach to authorization.
#
# Features:
# - Policy classes for each model (UserPolicy, PostPolicy, etc.)
# - Automatic policy lookup based on controller and action
# - Scopes for filtering collections
# - Test helpers for RSpec
#
# Architecture:
# - Each model has a corresponding Policy class
# - Policy methods match controller actions (show?, create?, update?, destroy?)
# - Scopes control which records users can access
#
# Example:
#   class PostPolicy < ApplicationPolicy
#     def update?
#       user.admin? || record.author == user
#     end
#   end
#
# Installation:
# After bundle install, run: rails g pundit:install

gem "pundit"

generate "pundit:install"
