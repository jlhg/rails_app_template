# Input Normalization

Handle leading/trailing whitespace in user input to ensure data consistency and query accuracy.

## Table of Contents

- [Overview](#overview)
- [Why Input Normalization is Needed](#why-input-normalization-is-needed)
- [Solution Options](#solution-options)
  - [Option 1: Rails 7.1+ normalizes (Recommended)](#option-1-rails-71-normalizes-recommended)
  - [Option 2: Model Callback](#option-2-model-callback)
  - [Option 3: Strong Parameters (Search Parameters)](#option-3-strong-parameters-search-parameters)
  - [Option 4: Using Gems](#option-4-using-gems)
- [Fields That Should Not Be Normalized](#fields-that-should-not-be-normalized)
- [Common Scenarios](#common-scenarios)
- [Testing Strategy](#testing-strategy)
- [Performance Considerations](#performance-considerations)
- [Summary and Recommendations](#summary-and-recommendations)

## Overview

User input often contains **unexpected leading/trailing whitespace**:

```ruby
# Users may copy-paste content with whitespace
params = {
  name: "  John Doe  ",
  email: " john@example.com ",
  username: "johndoe\n"
}
```

**Consequences of not handling this:**
- ❌ Search failures: `User.find_by(email: "john@example.com")` won't find `" john@example.com "`
- ❌ Duplicate data: `"John"` and `" John "` are treated as different values
- ❌ Validation errors: `validates :username, uniqueness: true` can't prevent `"user"` and `" user "`
- ❌ Display issues: Extra whitespace appears in the UI

**Benefits of normalization:**
- ✅ Data consistency: Store in unified format
- ✅ Query accuracy: Find data even when users input whitespace
- ✅ Prevent duplicates: Uniqueness validation works correctly
- ✅ Better UX: Clean, tidy display

## Why Input Normalization is Needed

### Real-World Problems

**Scenario 1: Login Failure**
```
User: "I entered the correct email, why can't I log in?"
→ User copy-pasted with trailing whitespace
→ Email query fails: " user@example.com " ≠ "user@example.com"
```

**Scenario 2: Duplicate Accounts**
```
User A registers: username = "johndoe"
User B registers: username = " johndoe "
→ Uniqueness validation passes (they are different)
→ System has two "johndoe" accounts
```

**Scenario 3: Search Returns No Results**
```
User searches: " iPhone 15 " (with leading/trailing whitespace)
→ Database: "iPhone 15"
→ Query fails, user thinks there are no products
```

### Which Layer Should Handle This?

**❌ Frontend handling is not enough**:
- Can be bypassed (direct API calls)
- Different frontends (web, mobile, CLI) need duplicate implementations
- Cannot handle existing dirty data

**✅ Backend handling (Model layer)**:
- Single source of truth
- All data sources are normalized
- Executes before validation, ensuring consistency

**✅ Controller layer handling for search parameters**:
- Search/filter scenarios need immediate handling
- No need to persist, only used for queries

## Solution Options

### Option 1: Rails 7.1+ normalizes (Recommended)

Rails 7.1+ introduced official API that automatically normalizes attributes before validation.

#### Basic Usage

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # Basic: strip leading/trailing whitespace
  normalizes :name, :username, with: -> value { value.strip }

  # Combine multiple normalizations
  normalizes :email, with: -> email { email.strip.downcase }

  # Phone number: remove non-numeric characters
  normalizes :phone, with: -> phone { phone.gsub(/\D/, '') }

  validates :email, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true
end
```

#### Handling nil Values

```ruby
class User < ApplicationRecord
  # Default: nil values are not processed
  normalizes :title, with: -> title { title.strip }
  # User.create(title: nil) → title = nil ✅

  # apply_to_nil: true → process nil values too
  normalizes :title,
    with: -> title { title&.strip || 'Untitled' },
    apply_to_nil: true
  # User.create(title: nil) → title = 'Untitled' ✅
end
```

#### Automatically Applied to Queries

```ruby
# Create user
user = User.create!(email: " JOHN@EXAMPLE.COM ")
# → Saved as: "john@example.com"

# Queries automatically normalize
User.find_by(email: "  JOHN@EXAMPLE.COM  ")
# → Automatically converts to: "john@example.com"
# → User found ✅

# No need to manually handle query parameters!
```

#### Batch Processing Multiple Fields

```ruby
class User < ApplicationRecord
  # Process multiple fields at once
  normalizes :first_name, :last_name, :middle_name,
    with: -> value { value.strip.titlecase }

  # Different logic for different fields
  normalizes :email, with: -> v { v.strip.downcase }
  normalizes :username, with: -> v { v.strip.downcase }
  normalizes :phone, with: -> v { v.gsub(/\D/, '') }
end
```

#### Advantages and Disadvantages

**✅ Advantages:**
- Rails official support (Rails 7.1+)
- **Automatically applies to finder queries** (biggest advantage)
- Executes before validation
- Declarative and clear
- Supports complex normalization logic
- Composable transformations

**❌ Disadvantages:**
- Rails 7.1+ only (This template uses Rails 8, so it's available)

---

### Option 2: Model Callback

Suitable for Rails < 7.1 or scenarios requiring more control.

#### For Specific Fields

```ruby
# app/models/user.rb
class User < ApplicationRecord
  before_validation :normalize_attributes

  private

  def normalize_attributes
    self.name = name.strip if name.present?
    self.email = email.strip.downcase if email.present?
    self.username = username.strip.downcase if username.present?
  end
end
```

#### Auto-Process All String Fields

```ruby
class User < ApplicationRecord
  before_validation :strip_string_attributes

  private

  # Skip fields that shouldn't be stripped
  SKIP_NORMALIZATION = %w[
    password
    password_digest
    encrypted_password
    description
    bio
    content
  ].freeze

  def strip_string_attributes
    attributes.each do |key, value|
      next if SKIP_NORMALIZATION.include?(key)
      next unless value.respond_to?(:strip)

      self[key] = value.strip if value.present?
    end
  end
end
```

#### Using Concern for Reusability

```ruby
# app/models/concerns/normalizable.rb
module Normalizable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_string_attributes
  end

  private

  def normalize_string_attributes
    self.class.normalized_attributes.each do |attr|
      value = send(attr)
      send("#{attr}=", value.strip) if value.respond_to?(:strip) && value.present?
    end
  end

  class_methods do
    def normalized_attributes
      @normalized_attributes ||= []
    end

    def normalize_attributes(*attrs)
      @normalized_attributes = attrs
    end
  end
end

# app/models/user.rb
class User < ApplicationRecord
  include Normalizable

  normalize_attributes :name, :email, :username
end
```

#### Advantages and Disadvantages

**✅ Advantages:**
- Supports all Rails versions
- Full control over normalization logic
- Can be customized for specific fields
- Can add complex conditional logic

**❌ Disadvantages:**
- Need to manually maintain field list
- **Does not automatically apply to finder queries**
- Easy to forget to add new fields
- More code required

---

### Option 3: Strong Parameters (Search Parameters)

**When to use:** Search forms, filter parameters (no need to persist to database)

#### Basic Usage

```ruby
# app/controllers/api/users_controller.rb
class Api::UsersController < ApplicationController
  def index
    # Search parameters: automatically strip
    users = User.where(search_params)
    render json: users
  end

  def create
    # Create parameters: let Model handle
    user = User.new(user_params)

    if user.save
      render json: user, status: :created
    else
      render json: { errors: user.errors }, status: :unprocessable_entity
    end
  end

  private

  # Search parameters: immediately strip
  def search_params
    params
      .permit(:name, :email, :username)
      .transform_values { |v| v.is_a?(String) ? v.strip : v }
      .compact_blank
  end

  # Create parameters: don't handle (let Model normalizes handle it)
  def user_params
    params.require(:user).permit(:name, :email, :username, :password)
  end
end
```

#### Handling Nested Parameters

```ruby
class Api::ProductsController < ApplicationController
  def index
    products = Product.where(search_params)
    render json: products
  end

  private

  def search_params
    sanitize_params(
      params.permit(:name, :category, tags: [], price: [:min, :max])
    )
  end

  def sanitize_params(params_hash)
    params_hash.deep_transform_values do |value|
      case value
      when String
        value.strip
      when Array
        value.map { |v| v.is_a?(String) ? v.strip : v }
      else
        value
      end
    end.compact_blank
  end
end
```

#### Using Concern for Reusability

```ruby
# app/controllers/concerns/parameter_sanitizer.rb
module ParameterSanitizer
  extend ActiveSupport::Concern

  private

  def sanitize_search_params(permitted_params)
    deep_strip(permitted_params).compact_blank
  end

  def deep_strip(value)
    case value
    when String
      value.strip
    when Array
      value.map { |v| deep_strip(v) }
    when Hash
      value.transform_values { |v| deep_strip(v) }
    else
      value
    end
  end
end

# app/controllers/api/users_controller.rb
class Api::UsersController < ApplicationController
  include ParameterSanitizer

  def index
    search = sanitize_search_params(params.permit(:name, :email, tags: []))
    users = User.where(search)
    render json: users
  end
end
```

#### Advantages and Disadvantages

**✅ Advantages:**
- Suitable for search/filter scenarios
- Does not affect database storage logic
- Can be combined with `compact_blank` to remove empty values
- Processes immediately, independent of Model

**❌ Disadvantages:**
- **Not suitable for data storage scenarios** (should be handled in Model)
- Need to replicate implementation in each controller (unless using concern)
- Queries still need manual handling (unlike normalizes auto)

---

### Option 4: Using Gems

Quick setup, reduces boilerplate, but adds dependencies.

#### strip_attributes (Recommended)

```ruby
# Gemfile
gem 'strip_attributes'

# app/models/user.rb
class User < ApplicationRecord
  # Auto strip all string and text fields
  strip_attributes

  # Or only specific fields
  strip_attributes only: [:name, :email, :username]

  # Exclude specific fields
  strip_attributes except: [:password, :description]

  # Allow empty strings (default converts to nil)
  strip_attributes allow_empty: true

  # Collapse consecutive spaces (multiple spaces → single space)
  strip_attributes collapse_spaces: true
end
```

**Examples:**
```ruby
# collapse_spaces: false (default)
user = User.create(name: "  John    Doe  ")
user.name  # => "John    Doe" (preserves middle extra spaces)

# collapse_spaces: true
class User < ApplicationRecord
  strip_attributes :name, collapse_spaces: true
end
user = User.create(name: "  John    Doe  ")
user.name  # => "John Doe" (collapses to single space)
```

#### auto_strip_attributes

```ruby
# Gemfile
gem 'auto_strip_attributes'

# app/models/user.rb
class User < ApplicationRecord
  # Basic usage
  auto_strip_attributes :name, :email

  # Preserve empty strings (don't convert to nil)
  auto_strip_attributes :title, nullify: false

  # Collapse extra spaces (squish)
  auto_strip_attributes :description, squish: true

  # Convert to lowercase
  auto_strip_attributes :email, downcase: true
end
```

**Examples:**
```ruby
# squish: true
user = User.create(description: "  This  is   a    description  ")
user.description  # => "This is a description"

# downcase: true
user = User.create(email: " JOHN@EXAMPLE.COM ")
user.email  # => "john@example.com"
```

#### Advantages and Disadvantages

**✅ Advantages:**
- Quick setup, less code
- Handles edge cases (nil, empty strings)
- Supports multiple normalization modes (collapse, squish, downcase)
- Battle-tested in production

**❌ Disadvantages:**
- Adds dependency (another gem)
- Implicit behavior (new developers may not be aware)
- Not suitable for complex normalization logic
- **Does not automatically apply to finder queries** (unless custom implementation)

---

## Fields That Should Not Be Normalized

### ❌ Password-Related Fields

```ruby
# ❌ Don't strip passwords
# Leading/trailing whitespace may be part of the password
class User < ApplicationRecord
  normalizes :email, with: -> v { v.strip.downcase }

  # Don't normalize: password, password_confirmation, encrypted_password
  # Let users decide if they want whitespace in passwords
end
```

**Reason:**
- Users may intentionally include whitespace in passwords (increases strength)
- Stripping leads to login failures
- Security standards don't recommend modifying user-inputted passwords

### ❌ JSON/YAML Fields

```ruby
class Setting < ApplicationRecord
  # ❌ Don't normalize JSON/YAML fields
  # normalizes :config, with: -> v { v.strip }  # Will break format

  # ✅ JSON fields don't need normalization
  # Rails automatically handles JSON serialization/deserialization
end
```

### ❌ Free-Text Fields (Depends on Requirements)

```ruby
class Post < ApplicationRecord
  normalizes :title, with: -> v { v.strip }  # ✅ Titles should be stripped

  # ❌ Don't strip content (may break formatting)
  # normalizes :content, with: -> v { v.strip }
  # normalizes :description, with: -> v { v.strip }

  # Users may intentionally add newlines at the beginning/end of content
end
```

**Exception:** If content is plain text and doesn't require formatting preservation, consider stripping.

### ❌ Code/Markdown Fields

```ruby
class CodeSnippet < ApplicationRecord
  normalizes :title, with: -> v { v.strip }  # ✅

  # ❌ Don't strip code
  # normalizes :code, with: -> v { v.strip }

  # Indentation at the beginning of code is meaningful
  # Markdown format depends on whitespace/newlines
end
```

### ✅ Fields That Should Be Normalized

```ruby
class User < ApplicationRecord
  # ✅ Most input should be normalized
  normalizes :name, :first_name, :last_name, with: -> v { v.strip }
  normalizes :email, with: -> v { v.strip.downcase }
  normalizes :username, with: -> v { v.strip.downcase }
  normalizes :phone, with: -> v { v.gsub(/\D/, '') }  # Remove non-numeric

  # ✅ Address
  normalizes :address, :city, :country, with: -> v { v.strip }

  # ✅ Title-type fields
  normalizes :title, :subject, :company_name, with: -> v { v.strip }
end
```

---

## Common Scenarios

### Scenario 1: Complete Email Normalization

```ruby
class User < ApplicationRecord
  # Email should: strip + downcase + unicode normalize
  normalizes :email, with: -> email do
    email.strip
         .downcase
         .unicode_normalize(:nfc)  # Unify Unicode encoding
  end

  validates :email,
    presence: true,
    uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
end

# Test
user = User.create(email: "  JOHN@EXAMPLE.COM  ")
user.email  # => "john@example.com"

# Queries automatically normalize
User.find_by(email: "  JOHN@EXAMPLE.COM  ")  # ✅ Found
```

### Scenario 2: Username

```ruby
class User < ApplicationRecord
  # Username: strip + downcase + remove special characters
  normalizes :username, with: -> username do
    username.strip
            .downcase
            .gsub(/[^a-z0-9_-]/, '')  # Only keep alphanumeric, underscore, hyphen
  end

  validates :username,
    presence: true,
    uniqueness: true,
    length: { minimum: 3, maximum: 20 }
end

# Test
user = User.create(username: "  John_Doe-123!@#  ")
user.username  # => "john_doe-123"
```

### Scenario 3: Phone Number

```ruby
class User < ApplicationRecord
  # Phone number: keep only numbers
  normalizes :phone, with: -> phone do
    phone.gsub(/\D/, '')  # Remove all non-numeric characters
  end

  validates :phone,
    presence: true,
    length: { is: 10 }  # Assume Taiwan phone number is 10 digits
end

# Test
user = User.create(phone: "(02) 1234-5678")
user.phone  # => "0212345678"

user = User.create(phone: "0912-345-678")
user.phone  # => "0912345678"
```

### Scenario 4: URL/Slug

```ruby
class Post < ApplicationRecord
  # Slug: strip + downcase + convert spaces to hyphens + remove special characters
  normalizes :slug, with: -> slug do
    slug.strip
        .downcase
        .gsub(/\s+/, '-')           # Convert spaces to hyphens
        .gsub(/[^a-z0-9\-]/, '')    # Remove special characters
        .gsub(/-+/, '-')            # Collapse multiple hyphens to one
        .gsub(/^-|-$/, '')          # Remove leading/trailing hyphens
  end

  validates :slug, presence: true, uniqueness: true
end

# Test
post = Post.create(slug: "  Hello World! 123  ")
post.slug  # => "hello-world-123"
```

### Scenario 5: Search Form (Controller Layer)

```ruby
# app/controllers/api/products_controller.rb
class Api::ProductsController < ApplicationController
  def index
    products = Product.where(search_conditions)
    render json: products
  end

  private

  def search_conditions
    {}.tap do |conditions|
      # Name search: use ILIKE (case insensitive)
      if params[:name].present?
        name = params[:name].strip
        conditions[:name] = Product.arel_table[:name].matches("%#{name}%")
      end

      # Category search: exact match
      if params[:category].present?
        conditions[:category] = params[:category].strip
      end

      # Tag search: array
      if params[:tags].present?
        tags = params[:tags].map(&:strip).compact_blank
        conditions[:tags] = tags
      end
    end
  end
end

# Frontend can input whitespace freely
# GET /api/products?name=  iPhone  &category= Electronics
# → Auto strips, queries normally
```

### Scenario 6: Multi-Language Content

```ruby
class Article < ApplicationRecord
  # Titles should be normalized
  normalizes :title_en, :title_zh, with: -> v { v.strip }

  # Content preserves original format (no normalization)
  # content_en, content_zh no processing
end
```

---

## Testing Strategy

### Testing normalizes

```ruby
# spec/models/user_spec.rb
RSpec.describe User, type: :model do
  describe 'attribute normalization' do
    context 'when creating user with whitespace' do
      let(:user) do
        User.create(
          name: '  John Doe  ',
          email: ' JOHN@EXAMPLE.COM ',
          username: ' JohnDoe '
        )
      end

      it 'strips whitespace from name' do
        expect(user.name).to eq 'John Doe'
      end

      it 'strips and lowercases email' do
        expect(user.email).to eq 'john@example.com'
      end

      it 'strips and lowercases username' do
        expect(user.username).to eq 'johndoe'
      end
    end

    context 'when nil values' do
      let(:user) { User.create(name: nil, email: 'test@example.com') }

      it 'preserves nil values' do
        expect(user.name).to be_nil
      end
    end

    context 'when empty string' do
      let(:user) { User.create(name: '   ', email: 'test@example.com') }

      it 'converts to empty string (not nil)' do
        expect(user.name).to eq ''
      end
    end
  end
end
```

### Testing Auto Query Normalization

```ruby
RSpec.describe User, type: :model do
  describe 'query normalization' do
    before do
      User.create(email: 'john@example.com', name: 'John')
    end

    context 'when searching with whitespace' do
      it 'finds user with leading/trailing whitespace' do
        user = User.find_by(email: '  john@example.com  ')
        expect(user).to be_present
        expect(user.name).to eq 'John'
      end

      it 'finds user with uppercase' do
        user = User.find_by(email: 'JOHN@EXAMPLE.COM')
        expect(user).to be_present
      end
    end
  end
end
```

### Testing Uniqueness Validation

```ruby
RSpec.describe User, type: :model do
  describe 'uniqueness validation' do
    before do
      User.create(email: 'john@example.com', username: 'johndoe')
    end

    context 'when creating duplicate with whitespace' do
      it 'rejects duplicate email with whitespace' do
        user = User.new(email: '  john@example.com  ')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('has already been taken')
      end

      it 'rejects duplicate username with different case' do
        user = User.new(username: 'JOHNDOE')
        expect(user).not_to be_valid
        expect(user.errors[:username]).to include('has already been taken')
      end
    end
  end
end
```

### Testing Controller Parameter Handling

```ruby
# spec/requests/users_spec.rb
RSpec.describe 'Users API', type: :request do
  describe 'GET /api/users' do
    before do
      create(:user, name: 'John Doe', email: 'john@example.com')
      create(:user, name: 'Jane Smith', email: 'jane@example.com')
    end

    context 'when searching with whitespace' do
      it 'finds users despite whitespace in query' do
        get '/api/users', params: { name: '  John  ' }

        expect(response).to have_http_status(:ok)
        users = JSON.parse(response.body)
        expect(users.size).to eq 1
        expect(users.first['name']).to eq 'John Doe'
      end
    end

    context 'when creating user with whitespace' do
      it 'strips whitespace before saving' do
        post '/api/users', params: {
          user: {
            name: '  Bob  ',
            email: ' bob@example.com '
          }
        }

        expect(response).to have_http_status(:created)
        user = User.last
        expect(user.name).to eq 'Bob'
        expect(user.email).to eq 'bob@example.com'
      end
    end
  end
end
```

### Testing Password Not Normalized

```ruby
RSpec.describe User, type: :model do
  describe 'password normalization' do
    context 'when password has whitespace' do
      let(:password) { '  secret123  ' }
      let(:user) { User.create(email: 'test@example.com', password: password) }

      it 'preserves whitespace in password' do
        # Can login with full password (including whitespace)
        expect(user.authenticate(password)).to eq user

        # Cannot login with stripped password
        expect(user.authenticate(password.strip)).to be false
      end
    end
  end
end
```

---

## Performance Considerations

### normalizes Performance

**Rails 7.1+ normalizes has excellent performance:**
- ✅ Only executes when attributes change (not on every read)
- ✅ Executes before validation (once)
- ✅ Does not affect read performance

**Benchmark:**
```ruby
require 'benchmark/ips'

# Test 1 million iterations
Benchmark.ips do |x|
  x.report('without normalization') do
    User.new(name: 'John Doe', email: 'john@example.com')
  end

  x.report('with normalizes') do
    User.new(name: '  John Doe  ', email: '  john@example.com  ')
  end

  x.compare!
end

# Result: Difference < 5% (negligible impact)
```

### Query Auto-Normalization Performance

**Rails 7.1+ automatically normalizes query parameters:**

```ruby
# This query automatically strips and downcases
User.find_by(email: '  JOHN@EXAMPLE.COM  ')

# Actual executed SQL (already normalized)
# SELECT * FROM users WHERE email = 'john@example.com' LIMIT 1
```

**Performance impact:**
- ✅ Minimal (< 0.1ms)
- ✅ Occurs at Ruby layer, not database layer
- ✅ Negligible compared to network latency (5-50ms)

### Bulk Data Processing

```ruby
# ❌ Bad: Update one by one (slow)
User.find_each do |user|
  user.update(email: user.email.strip.downcase)
end

# ✅ Good: Use SQL (fast)
User.where("email LIKE '% '").update_all(
  "email = TRIM(LOWER(email))"
)

# ✅ Better: Use normalizes, no batch update needed
# New data automatically normalized
# Old data automatically normalized on next update
```

---

## Summary and Recommendations

### Recommended Approach (By Scenario)

#### Scenario 1: Rails 8 New Project (This Template)

**✅ Use `normalizes` (Recommended)**

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # Basic fields
  normalizes :name, :username, :address, :city,
    with: -> v { v.strip }

  # Email: strip + downcase
  normalizes :email,
    with: -> v { v.strip.downcase }

  # Phone: keep only numbers
  normalizes :phone,
    with: -> v { v.gsub(/\D/, '') }

  validates :email, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true
end
```

#### Scenario 2: Global Configuration Needed

**Create Concern:**

```ruby
# app/models/concerns/normalizable.rb
module Normalizable
  extend ActiveSupport::Concern

  class_methods do
    def normalize_strings(*attributes, except: [])
      normalizes(*attributes.reject { |a| except.include?(a) },
        with: -> v { v.strip }
      )
    end
  end
end

# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  include Normalizable
  primary_abstract_class
end

# app/models/user.rb
class User < ApplicationRecord
  # Handle multiple fields in one line
  normalize_strings :name, :email, :username,
    except: [:password]

  # Custom special fields
  normalizes :email, with: -> v { v.strip.downcase }
end
```

#### Scenario 3: Search/Filter Parameters

**Controller Layer Handling:**

```ruby
# app/controllers/concerns/searchable.rb
module Searchable
  extend ActiveSupport::Concern

  private

  def sanitize_search_params(params_hash)
    params_hash.deep_transform_values do |value|
      value.is_a?(String) ? value.strip : value
    end.compact_blank
  end
end

# app/controllers/api/users_controller.rb
class Api::UsersController < ApplicationController
  include Searchable

  def index
    search = sanitize_search_params(
      params.permit(:name, :email, tags: [])
    )
    users = User.where(search)
    render json: users
  end
end
```

### Quick Decision Table

| Scenario | Recommended Approach | Reason |
|----------|---------------------|--------|
| Rails 8 new project | `normalizes` | Official support, auto query normalization |
| Rails < 7.1 | Model Callback / Gem | Compatibility |
| Search parameters | Controller Strong Parameters | No persist needed, immediate effect |
| Quick prototype | Gem (strip_attributes) | Quick setup |
| Complex logic | Model Callback | Full control |

### Checklist

**Before Implementation:**
- [ ] Confirm Rails version (7.1+ can use normalizes)
- [ ] List fields needing normalization
- [ ] Confirm fields that shouldn't be normalized (passwords, content, etc.)
- [ ] Determine normalization logic (strip, downcase, gsub, etc.)
- [ ] Write tests (create, query, uniqueness)
- [ ] Handle existing dirty data (migration or gradual normalization)

**Test Items:**
- [ ] Normalization on create
- [ ] Normalization on update
- [ ] nil value handling
- [ ] Empty string handling
- [ ] Auto query normalization (normalizes only)
- [ ] Uniqueness validation works correctly
- [ ] Passwords not normalized

### FAQ

**Q: What about existing data?**

A: Two options:

```ruby
# Option 1: One-time migration
class NormalizeUserAttributes < ActiveRecord::Migration[8.0]
  def up
    User.find_each do |user|
      user.update_columns(
        email: user.email.strip.downcase,
        name: user.name.strip
      )
    end
  end
end

# Option 2: Gradual normalization (recommended)
# Don't run migration, let normalizes handle it on next update
# Queries also auto-normalize, doesn't affect usage
```

**Q: Will it affect performance?**

A: Impact is minimal (< 0.1ms), negligible.

**Q: Should it also be done on frontend?**

A: You can but not mandatory. Frontend strip improves UX, backend strip ensures data consistency.

**Q: How to handle Unicode characters?**

A: Use `unicode_normalize(:nfc)` to unify encoding:

```ruby
normalizes :email, with: -> v { v.strip.downcase.unicode_normalize(:nfc) }
```

## References

- [Rails 7.1 normalizes API](https://api.rubyonrails.org/classes/ActiveRecord/Normalization/ClassMethods.html)
- [strip_attributes gem](https://github.com/rmm5t/strip_attributes)
- [auto_strip_attributes gem](https://github.com/holli/auto_strip_attributes)
- [Rails Guides: Callbacks](https://guides.rubyonrails.org/active_record_callbacks.html)
