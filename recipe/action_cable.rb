# ActionCable configuration for real-time WebSocket communication
# Provides bidirectional communication between server and clients
# Perfect for: notifications, chat, live updates

# Copy cable.yml configuration
# Rails 8.1+ creates config/cable.yml by default, so we need to remove it first
remove_file "config/cable.yml"
copy_file from_files("cable.yml"), "config/cable.yml"

# Mount ActionCable endpoint inside API scope
inject_into_file "config/routes.rb", after: 'scope path: "/api", as: "api" do' do
  <<~RUBY

    mount ActionCable.server => "/cable"
  RUBY
end

# Configure ActionCable for production
environment <<-CODE, env: "production"
  # ActionCable WebSocket URL
  config.action_cable.url = ENV.fetch('ACTION_CABLE_URL', 'ws://localhost:3000/cable')

  # Allow requests from specified origins
  # Set to array of domains in production for security
  config.action_cable.allowed_request_origins = ENV.fetch('ACTION_CABLE_ALLOWED_ORIGINS', '*').split(',').map(&:strip)

  # Disable request forgery protection for API mode
  config.action_cable.disable_request_forgery_protection = ENV.fetch('ACTION_CABLE_DISABLE_FORGERY_PROTECTION', 'true') == 'true'
CODE

# Configure ActionCable for development
environment <<-'CODE', env: "development"
  # ActionCable WebSocket URL for development
  config.action_cable.url = 'ws://localhost:3000/cable'

  # Allow all origins in development
  config.action_cable.allowed_request_origins = [/http:\/\/localhost:\d+/]

  # Disable request forgery protection in development
  config.action_cable.disable_request_forgery_protection = true
CODE

# Create ApplicationCable::Connection for authentication
create_file "app/channels/application_cable/connection.rb", <<~RUBY
  module ApplicationCable
    class Connection < ActionCable::Connection::Base
      identified_by :current_user

      def connect
        self.current_user = find_verified_user
      end

      private

      def find_verified_user
        # Extract token with priority: Sec-WebSocket-Protocol > Authorization > params
        # Sec-WebSocket-Protocol is the most secure method for WebSocket authentication
        # Reference: https://github.com/ruilisi/actioncable-jwt
        token = extract_token_from_websocket_protocol ||
                extract_token_from_header ||
                request.params[:token]

        if token.present?
          # Verify JWT token (assumes you have JWT gem configured)
          begin
            decoded_token = JWT.decode(
              token,
              Rails.application.secret_key_base,
              true,
              { algorithm: "HS256" }
            )

            # Find user by ID from token payload
            user_id = decoded_token[0]["user_id"]
            user = User.find_by(id: user_id)

            return user if user.present?
          rescue JWT::DecodeError, ActiveRecord::RecordNotFound
            # Invalid token or user not found
          end
        end

        # Reject unauthorized connections
        reject_unauthorized_connection
      end

      def extract_token_from_websocket_protocol
        # Extract JWT token from Sec-WebSocket-Protocol header
        # Client should send: Sec-WebSocket-Protocol: protocol1, protocol2, jwt_token
        # The token is typically the last protocol in the list
        if request.headers["Sec-WebSocket-Protocol"].present?
          protocols = request.headers["Sec-WebSocket-Protocol"].split(",")
          protocols.last&.strip
        end
      end

      def extract_token_from_header
        # Extract from Authorization header if present
        # Format: Authorization: Bearer jwt_token
        if request.headers["Authorization"].present?
          request.headers["Authorization"].split.last
        end
      end
    end
  end
RUBY

# Create ApplicationCable::Channel base class
create_file "app/channels/application_cable/channel.rb", <<~RUBY
  module ApplicationCable
    class Channel < ActionCable::Channel::Base
    end
  end
RUBY

# Create example NotificationsChannel
create_file "app/channels/notifications_channel.rb", <<~RUBY
  # Example channel for real-time notifications
  #
  # Client-side usage (JavaScript):
  #
  # Method 1 (Recommended): Use Sec-WebSocket-Protocol header
  #   const cable = ActionCable.createConsumer('ws://localhost:3000/cable', {
  #     subprotocols: ['actioncable-v1-json', 'YOUR_JWT_TOKEN']
  #   });
  #
  # Method 2: Use Authorization header (requires custom adapter)
  #   const cable = ActionCable.createConsumer('ws://localhost:3000/cable', {
  #     headers: { 'Authorization': 'Bearer YOUR_JWT_TOKEN' }
  #   });
  #
  # Method 3 (Least secure): Use URL params
  #   const cable = ActionCable.createConsumer('ws://localhost:3000/cable?token=YOUR_JWT_TOKEN');
  #
  #   cable.subscriptions.create('NotificationsChannel', {
  #     received(data) {
  #       console.log('Received notification:', data);
  #     }
  #   });
  #
  # Server-side broadcasting:
  #
  #   ActionCable.server.broadcast(
  #     "notifications:\#{user.id}",
  #     { message: 'New order created', order_id: 123 }
  #   )
  #
  class NotificationsChannel < ApplicationCable::Channel
    def subscribed
      # Stream notifications for the current user
      stream_from "notifications:\#{current_user.id}"
    end

    def unsubscribed
      # Cleanup when channel is unsubscribed
      stop_all_streams
    end
  end
RUBY

# Add helper method to broadcast notifications
initializer "action_cable_helpers.rb", <<-CODE
  # Helper module for broadcasting ActionCable messages
  module ActionCableHelpers
    # Broadcast notification to a specific user
    #
    # Example:
    #   ActionCableHelpers.notify_user(user, { message: 'Hello', data: {...} })
    #
    def self.notify_user(user, data)
      ActionCable.server.broadcast(
        "notifications:\#{user.id}",
        data.merge(timestamp: Time.current.iso8601)
      )
    end

    # Broadcast to all users (use sparingly)
    #
    # Example:
    #   ActionCableHelpers.broadcast_to_all({ announcement: 'System maintenance in 5 minutes' })
    #
    def self.broadcast_to_all(data)
      ActionCable.server.broadcast(
        "global_notifications",
        data.merge(timestamp: Time.current.iso8601)
      )
    end
  end
CODE

say "ActionCable configured successfully!"
say ""
say "Next steps:"
say "  1. Ensure Redis is running (required for production)"
say "  2. Configure ACTION_CABLE_URL in production environment"
say "  3. Set ACTION_CABLE_ALLOWED_ORIGINS to your frontend domain(s)"
say "  4. Adjust WEB_CONCURRENCY and RAILS_MAX_THREADS for WebSocket connections"
say ""
say "Client-side connection example (Sec-WebSocket-Protocol - recommended):"
say "  const cable = ActionCable.createConsumer('ws://localhost:3000/cable', {"
say "    subprotocols: ['actioncable-v1-json', 'YOUR_JWT_TOKEN']"
say "  });"
say "  cable.subscriptions.create('NotificationsChannel', {"
say "    received(data) { console.log(data); }"
say "  });"
say ""
say "Broadcasting example:"
say "  ActionCableHelpers.notify_user(user, { message: 'New notification' })"
