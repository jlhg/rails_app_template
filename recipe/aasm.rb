# AASM - State Machine
# https://github.com/aasm/aasm
#
# AASM provides a simple DSL for defining state machines in Ruby objects.
# Commonly used for:
# - Order status (pending -> paid -> shipped -> delivered)
# - User registration flow (unverified -> active -> suspended)
# - Job/task states (queued -> processing -> completed -> failed)
#
# Example:
#   class Order
#     include AASM
#     aasm do
#       state :pending, initial: true
#       state :paid, :shipped, :delivered
#       event :pay do
#         transitions from: :pending, to: :paid
#       end
#     end
#   end

gem "aasm"
