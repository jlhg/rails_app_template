# Per-Request Global State with CurrentAttributes

Rails built-in `ActiveSupport::CurrentAttributes` provides thread-safe per-request global variables without needing the `request_store` gem.

## Overview

**CurrentAttributes** is a feature introduced in Rails 5.2+ for storing "current request" global state:
- ✅ **Thread-safe**: Each request has its own variable space
- ✅ **Auto cleanup**: Automatically resets after request ends
- ✅ **Type-safe**: Uses attributes instead of hash keys
- ✅ **Rails native**: No additional gems needed

## Why Not Use request_store?

After Rails 5.2+, the `request_store` gem has been replaced by CurrentAttributes:

```ruby
# ❌ Old way (request_store gem)
RequestStore.store[:current_user] = user
user = RequestStore.store[:current_user]

# ✅ New way (Rails built-in)
Current.user = user
user = Current.user
```

**Advantages**:
- No need to install additional gems
- Type-safe (attributes instead of Hash)
- Officially supported and maintained by Rails

## Basic Usage

### 1. Create Current Class

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  # Define attributes to store per request
  attribute :user, :account, :request_id, :user_agent
end
```

### 2. Set in Controller

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  before_action :set_current_request_details
  before_action :authenticate_user!

  private

  def set_current_request_details
    Current.request_id = request.uuid
    Current.user_agent = request.user_agent
  end

  def authenticate_user!
    token = extract_token_from_header
    user = verify_token(token)

    if user
      Current.user = user
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
```

### 3. Use Anywhere

```ruby
# app/services/order_service.rb
class OrderService
  def create_order(params)
    # No need to pass user parameter
    Order.create!(
      params.merge(
        user_id: Current.user.id,
        created_by_ip: Current.request_id
      )
    )
  end
end

# app/models/audit_log.rb
class AuditLog < ApplicationRecord
  before_create :set_request_context

  private

  def set_request_context
    self.user_id ||= Current.user&.id
    self.request_id ||= Current.request_id
  end
end
```

## Common Use Cases

### Scenario 1: Multi-tenancy

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :account
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  before_action :set_current_account

  private

  def set_current_account
    # Get account from subdomain or header
    subdomain = request.subdomain
    Current.account = Account.find_by!(subdomain: subdomain)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Account not found" }, status: :not_found
  end
end

# app/models/post.rb
class Post < ApplicationRecord
  belongs_to :account

  # Automatically scope queries to current account
  default_scope { where(account: Current.account) }

  before_create :set_account

  private

  def set_account
    self.account = Current.account
  end
end

# Usage example
# GET https://acme.example.com/api/posts
# → Only returns ACME account's posts
```

### Scenario 2: Request Tracing

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :request_id, :user, :ip_address
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  before_action :set_request_context

  private

  def set_request_context
    Current.request_id = request.uuid
    Current.ip_address = request.remote_ip
  end
end

# config/initializers/logger.rb
class RequestLogger
  def self.info(message)
    Rails.logger.info({
      message: message,
      request_id: Current.request_id,
      user_id: Current.user&.id,
      ip_address: Current.ip_address,
      timestamp: Time.current.iso8601
    }.to_json)
  end
end

# Usage example
# app/services/payment_service.rb
class PaymentService
  def process_payment(amount)
    RequestLogger.info("Processing payment: #{amount}")
    # ... payment logic
    RequestLogger.info("Payment completed")
  end
end

# Log output:
# {"message":"Processing payment: 100","request_id":"abc-123","user_id":42,"ip_address":"1.2.3.4","timestamp":"2025-01-15T10:30:00Z"}
```

### Scenario 3: Time Zone Handling

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :user

  # Automatically set time zone when user changes
  resets { Time.zone = nil }

  def user=(user)
    super
    Time.zone = user&.time_zone || "UTC"
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  before_action :authenticate_user!

  private

  def authenticate_user!
    Current.user = User.find_by(token: request.headers["Authorization"])
  end
end

# Usage example
# app/controllers/posts_controller.rb
def index
  # Time.zone is already set to Current.user.time_zone
  @posts = Post.where("created_at > ?", 1.day.ago)
  # → Uses user's time zone to calculate 1.day.ago
end
```

### Scenario 4: API Version Management

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :api_version
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  before_action :set_api_version

  private

  def set_api_version
    # Get version from URL or header
    Current.api_version = params[:api_version] ||
                          request.headers["X-API-Version"] ||
                          "v1"
  end
end

# app/serializers/user_serializer.rb
class UserSerializer
  def as_json
    base = {
      id: user.id,
      name: user.name,
      email: user.email
    }

    # Return different fields based on API version
    if Current.api_version == "v2"
      base.merge!(
        created_at: user.created_at,
        updated_at: user.updated_at
      )
    end

    base
  end
end
```

## Best Practices

### ✅ Appropriate Use Cases

1. **Top-level global variables**
   - `current_user` - Currently logged in user
   - `current_account` - Current account in multi-tenant apps
   - `request_id` - Request tracking ID

2. **Cross-layer context**
   - Data needed from Controller → Service → Model
   - Avoid passing same parameters in every method signature

3. **Audit Trail / Logging**
   - Automatically record "who, when, from where" for operations

### ⚠️ Usage to Avoid

1. **Overuse leading to hidden dependencies**
   ```ruby
   # ❌ Bad: Hidden dependency, hard to test
   class OrderService
     def calculate_total
       discount = Current.promotion.discount  # Non-obvious dependency
       price * (1 - discount)
     end
   end

   # ✅ Good: Explicit parameter passing
   class OrderService
     def calculate_total(promotion:)
       discount = promotion.discount
       price * (1 - discount)
     end
   end
   ```

2. **Storing frequently changing state**
   ```ruby
   # ❌ Bad: Modifying multiple times during request
   Current.step = "processing"
   # ... do something
   Current.step = "completed"  # Easily confusing

   # ✅ Good: Use local variables or state machine
   step = "processing"
   # ... do something
   step = "completed"
   ```

3. **Using in Background Jobs**
   ```ruby
   # ❌ Bad: Background job has no request context
   class ProcessOrderJob < ApplicationJob
     def perform(order_id)
       Current.user  # → nil (not in request)
     end
   end

   # ✅ Good: Explicitly pass required data
   class ProcessOrderJob < ApplicationJob
     def perform(order_id, user_id)
       user = User.find(user_id)
       # ...
     end
   end
   ```

## Testing Considerations

### RSpec Configuration

CurrentAttributes automatically resets after each request, but in tests need manual handling:

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  # Reset Current after each test
  config.after do
    Current.reset
  end
end
```

### Test Examples

```ruby
# spec/services/order_service_spec.rb
RSpec.describe OrderService do
  describe "#create_order" do
    let(:user) { create(:user) }

    before do
      # Set Current in tests
      Current.user = user
    end

    it "creates order with current user" do
      service = OrderService.new
      order = service.create_order(product_id: 1, quantity: 2)

      expect(order.user_id).to eq(user.id)
    end
  end
end

# spec/requests/posts_spec.rb
RSpec.describe "Posts API" do
  describe "GET /posts" do
    let(:account) { create(:account) }

    before do
      # Simulate subdomain
      host! "#{account.subdomain}.example.com"
    end

    it "returns posts for current account" do
      other_post = create(:post)  # Different account
      my_post = create(:post, account: account)

      get "/api/posts"

      expect(response).to have_http_status(:ok)
      post_ids = JSON.parse(response.body).map { |p| p["id"] }
      expect(post_ids).to include(my_post.id)
      expect(post_ids).not_to include(other_post.id)
    end
  end
end
```

## Monitoring and Debugging

### Check Current Context

```ruby
# app/controllers/debug_controller.rb
class DebugController < ApplicationController
  def current_context
    render json: {
      user_id: Current.user&.id,
      account_id: Current.account&.id,
      request_id: Current.request_id,
      user_agent: Current.user_agent
    }
  end
end
```

### Log Output

```ruby
# config/initializers/current_attributes_logging.rb
class Current < ActiveSupport::CurrentAttributes
  # Log when user is set
  def user=(value)
    super
    Rails.logger.debug("Current.user set to: #{value&.id}")
  end
end
```

## Performance Considerations

CurrentAttributes uses thread-local storage with minimal performance impact:

- ✅ **Read speed**: ~0.001ms (comparable to local variables)
- ✅ **Memory**: Per-thread independent storage, auto-cleanup
- ⚠️ **Avoid**: Storing large objects (like complete associated data)

```ruby
# ❌ Bad: Storing large objects
Current.user_with_posts = User.includes(:posts).find(1)

# ✅ Good: Only store ID, query when needed
Current.user = User.find(1)
# When needed: Current.user.posts
```

## Summary

**When to Use CurrentAttributes:**
- ✅ Need to share top-level context across multiple layers
- ✅ Avoid passing same parameters in every method signature
- ✅ Automated audit logging

**When to Avoid:**
- ❌ Data that can be passed as parameters
- ❌ Frequently changing temporary state
- ❌ Background jobs (no request context)

**Remember DHH's Advice:**
> "CurrentAttributes should be used sparingly, for a few, top-level globals like account, user, and request details."

## References

- [Rails API: ActiveSupport::CurrentAttributes](https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html)
- [GoRails: Rails CurrentAttributes Tutorial](https://gorails.com/episodes/rails-active-support-current-attributes)
