# Cloudflare Tunnel Configuration Guide

This guide explains how to configure Cloudflare Tunnel for your Rails API with **WebSocket support** for ActionCable.

## Table of Contents

- [Overview](#overview)
- [Why Cloudflare Tunnel?](#why-cloudflare-tunnel)
- [Setup Instructions](#setup-instructions)
- [WebSocket Configuration](#websocket-configuration)
- [ActionCable Integration](#actioncable-integration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)
- [Performance Considerations](#performance-considerations)
- [Advanced Topics](#advanced-topics)

## Overview

Cloudflare Tunnel provides secure remote access to your Rails application without exposing ports or requiring a public IP address.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet Users                            │
│              https://api.yourdomain.com                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │  Cloudflare Network    │
            │  - DDoS Protection     │
            │  - SSL/TLS             │
            │  - Caching             │
            │  - WebSocket Support   │
            └────────────┬───────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │  Cloudflare Tunnel     │
            │  (cloudflared)         │◄────── Outbound only
            │  - No inbound ports    │        (no firewall config)
            │  - Encrypted tunnel    │
            └────────────┬───────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │  Your Rails App        │
            │  - Web (port 3000)     │
            │  - ActionCable (/cable)│
            └────────────────────────┘
```

**Key Points:**
- No inbound firewall rules needed
- Outbound-only connections (cloudflared → Cloudflare)
- Automatic SSL/TLS termination
- Built-in DDoS protection
- **WebSocket support** for real-time features

## Why Cloudflare Tunnel?

### Advantages

✅ **Security:**
- No exposed ports (no SSH, no open HTTP/HTTPS)
- Cloudflare handles SSL/TLS certificates
- Built-in DDoS and bot protection
- Zero Trust access policies (optional)

✅ **Simplicity:**
- No need for reverse proxy (nginx, Caddy)
- No Let's Encrypt certificate management
- Works behind NAT/firewall without configuration
- Single container deployment

✅ **Performance:**
- Cloudflare's global CDN
- Automatic static asset caching (if enabled)
- HTTP/2 and HTTP/3 support
- WebSocket compression

✅ **Cost:**
- Free tier available
- No additional infrastructure needed

### Limitations

⚠️ **WebSocket Timeout:**
- **Free plan**: 100 seconds
- **Pro/Business**: 600 seconds (10 minutes)
- **Enterprise**: Unlimited
- **Solution**: ActionCable has built-in auto-reconnect

⚠️ **Concurrency:**
- Single cloudflared instance: ~1,000 concurrent WebSocket connections
- **Solution**: Run multiple replicas (same tunnel)

⚠️ **Latency:**
- Adds ~20-50ms compared to direct connection
- **Acceptable** for most API and WebSocket use cases

## Setup Instructions

### Step 1: Create Cloudflare Tunnel

1. **Login to Cloudflare Zero Trust:**
   - Go to: https://one.dash.cloudflare.com/
   - Navigate to: **Access → Tunnels**

2. **Create a new tunnel:**
   ```
   Click "Create a tunnel"
   Name: my-rails-app (or any name you prefer)
   Click "Save tunnel"
   ```

3. **Download credentials:**
   - After creation, Cloudflare shows a credentials JSON
   - Save this JSON (you'll need it in Step 2)
   - Example format:
   ```json
   {
     "AccountTag": "abc123...",
     "TunnelSecret": "xyz789...",
     "TunnelID": "a1b2c3d4-..."
   }
   ```

4. **Note your Tunnel ID:**
   - Copy the UUID (e.g., `a1b2c3d4-e5f6-7890-abcd-ef1234567890`)
   - You'll need this for the config file

### Step 2: Configure Tunnel Credentials

```bash
# Navigate to your project's .secrets directory
cd .secrets

# Create cf_tunnel_token file with the credentials JSON
cat > cf_tunnel_token << 'EOF'
{
  "AccountTag": "your-account-tag-here",
  "TunnelSecret": "your-tunnel-secret-here",
  "TunnelID": "your-tunnel-id-here"
}
EOF

# Set proper permissions
chmod 640 cf_tunnel_token

cd ..
```

**IMPORTANT:** The credentials JSON must be valid. Verify with:
```bash
cat .secrets/cf_tunnel_token | jq .
```

### Step 3: Configure Tunnel Ingress Rules

```bash
# Copy the example config
cp cloudflared-config.yaml.example cloudflared-config.yaml

# Edit the config file
nano cloudflared-config.yaml
```

**Minimal configuration for ActionCable:**

```yaml
tunnel: a1b2c3d4-e5f6-7890-abcd-ef1234567890  # Your Tunnel ID
credentials-file: /run/secrets/cf_tunnel_token
metrics: 0.0.0.0:41111

ingress:
  # WebSocket route (ActionCable) - MUST come first
  - hostname: api.yourdomain.com
    path: /cable
    service: http://web:3000
    originRequest:
      noTLSVerify: true
      http2Origin: false        # CRITICAL for WebSocket
      keepAliveTimeout: 90s     # Long timeout for WebSocket

  # General API routes
  - hostname: api.yourdomain.com
    service: http://web:3000
    originRequest:
      noTLSVerify: true

  # Catch-all (required)
  - service: http_status:404
```

**What to replace:**
- `a1b2c3d4-e5f6-7890-abcd-ef1234567890` → Your Tunnel ID
- `api.yourdomain.com` → Your actual domain

### Step 4: Configure DNS

In Cloudflare Dashboard (not Zero Trust):

1. Go to your domain's **DNS** settings
2. Add a CNAME record:
   ```
   Type: CNAME
   Name: api (or @ for root domain)
   Target: <tunnel-id>.cfargotunnel.com
   Proxy status: Proxied (orange cloud)
   ```

The tunnel ID is shown in Zero Trust → Tunnels → Your tunnel.

### Step 5: Configure Rails Environment

Edit `.env` (or set environment variables):

```bash
# ActionCable WebSocket URL
ACTION_CABLE_URL=wss://api.yourdomain.com/cable

# Allowed origins for WebSocket connections
ACTION_CABLE_ALLOWED_ORIGINS=https://api.yourdomain.com,https://app.yourdomain.com

# Or allow all (only for development/testing)
# ACTION_CABLE_ALLOWED_ORIGINS=*
```

### Step 6: Start Services

```bash
# Start Rails app + Cloudflare Tunnel
docker compose --profile cloudflare up -d

# Check tunnel status
docker compose logs cloudflared

# You should see:
# "Registered tunnel connection"
# "Serve tunnel runs successfully"
```

### Step 7: Verify Setup

```bash
# Test HTTPS connection
curl https://api.yourdomain.com/up

# Check tunnel health
docker compose exec cloudflared wget -qO- http://localhost:41111/ready
```

## WebSocket Configuration

### Critical Settings for ActionCable

**In `cloudflared-config.yaml`:**

```yaml
ingress:
  - hostname: api.yourdomain.com
    path: /cable
    service: http://web:3000
    originRequest:
      # CRITICAL: Force HTTP/1.1 (WebSocket cannot use HTTP/2)
      http2Origin: false

      # Recommended: Long timeout for persistent connections
      keepAliveTimeout: 90s
      tcpKeepAlive: 30s

      # Recommended: Disable TLS verification (backend is http)
      noTLSVerify: true
```

**Why `http2Origin: false` is critical:**
- WebSocket protocol requires HTTP/1.1 upgrade
- HTTP/2 doesn't support protocol upgrade
- Without this setting, WebSocket connections will fail

**Why `keepAliveTimeout: 90s`:**
- Prevents tunnel from closing idle WebSocket connections
- ActionCable sends ping every 3 seconds (keeps connection alive)
- 90s is safe margin (Cloudflare free plan timeout is 100s)

### Cloudflare Dashboard Settings

Ensure WebSocket is enabled globally:

1. Cloudflare Dashboard → **Network**
2. **WebSocket**: ON (should be enabled by default)

## ActionCable Integration

### Frontend Configuration

**JavaScript (ActionCable.js):**

```javascript
// Use secure WebSocket (wss://) via Cloudflare Tunnel
const cable = ActionCable.createConsumer('wss://api.yourdomain.com/cable');

cable.subscriptions.create('NotificationsChannel', {
  connected() {
    console.log('WebSocket connected via Cloudflare');
  },

  disconnected() {
    console.log('WebSocket disconnected');
    // ActionCable automatically reconnects
  },

  received(data) {
    console.log('Received:', data);
  }
});
```

**React Native / Mobile Apps:**

```javascript
import ActionCable from '@rails/actioncable';

const cable = ActionCable.createConsumer('wss://api.yourdomain.com/cable');
```

### Backend Configuration

**Rails config/cable.yml** (already configured in template):

```yaml
production:
  adapter: redis
  url: <%= redis_cable_url %>
```

**Broadcasting from Rails:**

```ruby
# Send notification to specific user
ActionCable.server.broadcast(
  "notifications:#{user.id}",
  {
    type: 'new_message',
    data: { message: 'Hello from Cloudflare Tunnel!' }
  }
)
```

### Auto-Reconnection (Important for Free Plan)

ActionCable.js has **built-in auto-reconnection**:

- If connection drops (e.g., 100s timeout on free plan), client automatically reconnects
- Exponential backoff: 1s → 2s → 4s → ... up to 60s
- No manual configuration needed

**Custom reconnection logic (optional):**

```javascript
const cable = ActionCable.createConsumer('wss://api.yourdomain.com/cable', {
  // Custom reconnection intervals
  reconnectDelay: (attempt) => {
    return Math.min(1000 * Math.pow(2, attempt), 60000);
  }
});
```

## Testing

### Test REST API

```bash
# Health check
curl https://api.yourdomain.com/up

# Should return 200 OK
```

### Test WebSocket Connection

**Browser Console:**

```javascript
// Open WebSocket connection
const ws = new WebSocket('wss://api.yourdomain.com/cable');

ws.onopen = () => {
  console.log('✅ WebSocket connected');

  // Subscribe to a channel
  ws.send(JSON.stringify({
    command: 'subscribe',
    identifier: JSON.stringify({ channel: 'NotificationsChannel' })
  }));
};

ws.onmessage = (event) => {
  console.log('Received:', event.data);
};

ws.onerror = (error) => {
  console.error('❌ WebSocket error:', error);
};

ws.onclose = (event) => {
  console.log('WebSocket closed:', event.code, event.reason);
};
```

**Expected output:**
```
✅ WebSocket connected
Received: {"type":"welcome"}
Received: {"type":"ping","message":1234567890}
Received: {"type":"confirm_subscription","identifier":"..."}
```

### Test ActionCable (Full Integration)

**Frontend:**

```javascript
const cable = ActionCable.createConsumer('wss://api.yourdomain.com/cable');

const subscription = cable.subscriptions.create('NotificationsChannel', {
  connected() {
    console.log('✅ ActionCable connected');
  },
  received(data) {
    console.log('📨 Received:', data);
  }
});
```

**Backend (Rails console):**

```ruby
# Broadcast test message
ActionCable.server.broadcast('notifications:123', {
  type: 'test',
  message: 'Hello from Rails!'
})
```

### Check Tunnel Logs

```bash
# Real-time logs
docker compose logs -f cloudflared

# Look for:
# "connection registered" - Tunnel connected to Cloudflare
# "Upgrading to websocket" - WebSocket upgrade successful
# "EOF" - Connection closed
```

### Check Rails Logs

```bash
# ActionCable logs
docker compose logs -f web | grep -i cable

# Look for:
# "Started GET "/cable" for ..." - WebSocket connection attempt
# "Successfully upgraded to WebSocket" - Connection established
# "Registered connection" - User subscribed to channel
```

## Troubleshooting

### WebSocket Connection Fails

**Symptom:** WebSocket connection closes immediately or never connects.

**Checklist:**

1. **Verify `http2Origin: false` in config:**
   ```bash
   grep -A5 "/cable" cloudflared-config.yaml | grep http2Origin
   # Should show: http2Origin: false
   ```

2. **Check Cloudflare WebSocket setting:**
   - Cloudflare Dashboard → Network → WebSocket: ON

3. **Verify allowed origins:**
   ```bash
   # Check Rails environment
   docker compose exec web rails runner 'puts ENV["ACTION_CABLE_ALLOWED_ORIGINS"]'
   # Should include your domain
   ```

4. **Check cloudflared logs:**
   ```bash
   docker compose logs cloudflared | grep -i websocket
   # Should see "Upgrading to websocket"
   ```

5. **Test direct connection (bypass tunnel):**
   ```javascript
   // Test direct connection to Rails (from same network)
   const ws = new WebSocket('ws://localhost:3000/cable');
   // If this works, issue is with tunnel config
   ```

### Connection Drops After 100 Seconds

**Symptom:** WebSocket disconnects exactly at 100 seconds.

**Cause:** Cloudflare Free plan timeout.

**Solutions:**

1. **Verify auto-reconnect works:**
   - ActionCable.js reconnects automatically
   - Check browser console for reconnection attempts

2. **Upgrade Cloudflare plan:**
   - Pro/Business: 600 seconds
   - Enterprise: Unlimited

3. **Monitor connection health:**
   ```javascript
   let reconnectCount = 0;

   cable.subscriptions.create('NotificationsChannel', {
     disconnected() {
       reconnectCount++;
       console.log(`Reconnecting... (attempt ${reconnectCount})`);
     }
   });
   ```

### Cloudflared Won't Start

**Symptom:** `docker compose logs cloudflared` shows errors.

**Common issues:**

1. **Invalid credentials JSON:**
   ```bash
   # Validate JSON
   cat .secrets/cf_tunnel_token | jq .
   # Should parse without errors
   ```

2. **Wrong tunnel ID:**
   ```bash
   # Extract tunnel ID from credentials
   cat .secrets/cf_tunnel_token | jq -r '.TunnelID'
   # Must match tunnel ID in cloudflared-config.yaml
   ```

3. **Missing config file:**
   ```bash
   ls -l cloudflared-config.yaml
   # Should exist and be readable
   ```

4. **Permission errors:**
   ```bash
   ls -l .secrets/cf_tunnel_token
   # Should show: -rw-r----- (640)
   chmod 640 .secrets/cf_tunnel_token
   ```

### High Latency

**Symptom:** Slow API responses or WebSocket message delays.

**Diagnosis:**

```bash
# Measure latency
time curl -so /dev/null https://api.yourdomain.com/up

# Should be < 500ms for most regions
```

**Causes:**

1. **Geographic distance:**
   - Cloudflare routes to nearest datacenter
   - Your server might be far from Cloudflare edge
   - **Solution:** Deploy closer to Cloudflare datacenters

2. **Tunnel overhead:**
   - Adds ~20-50ms encryption overhead
   - **Normal** and acceptable for most use cases

3. **Origin performance:**
   - Check Rails app performance separately
   ```bash
   # Test direct connection (from server)
   docker compose exec web time curl -so /dev/null http://localhost:3000/up
   ```

### "Too Many Connections" Error

**Symptom:** Some WebSocket connections rejected.

**Cause:** Hit connection limit (free plan: ~1,000 concurrent)

**Solutions:**

1. **Run multiple cloudflared replicas:**
   ```yaml
   # compose.yaml
   cloudflared:
     deploy:
       replicas: 3  # 3x capacity
   ```

2. **Upgrade Cloudflare plan:**
   - Higher connection limits
   - Better performance

3. **Use AnyCable:**
   - Reduces connection overhead
   - See [AnyCable documentation](https://anycable.io/)

## Security Best Practices

### 1. Credential Management

✅ **DO:**
- Store credentials in `.secrets/cf_tunnel_token` (gitignored)
- Use proper file permissions (640)
- Rotate tunnel credentials regularly

❌ **DON'T:**
- Commit credentials to git
- Share credentials via email/chat
- Use world-readable permissions (644, 666, 777)

### 2. Origin Validation

✅ **DO:**
- Set specific `ACTION_CABLE_ALLOWED_ORIGINS`
  ```bash
  ACTION_CABLE_ALLOWED_ORIGINS=https://app.yourdomain.com
  ```

❌ **DON'T:**
- Use `*` in production
  ```bash
  ACTION_CABLE_ALLOWED_ORIGINS=*  # Only for development!
  ```

### 3. Cloudflare Access Policies (Optional)

Add authentication layer before tunnel:

1. **Zero Trust Dashboard → Access → Applications**
2. **Create an application:**
   ```
   Name: Rails API
   Domain: api.yourdomain.com
   ```
3. **Add policy:**
   ```
   Rule name: Require login
   Criteria: Emails ending in @yourcompany.com
   ```

Now users must authenticate before accessing your API.

### 4. Rate Limiting

Use both Cloudflare and Rails-level rate limiting:

**Cloudflare (Dashboard → Security → WAF):**
- Configure rate limiting rules
- Block by IP, country, etc.

**Rails (Rack::Attack):**
```ruby
# config/initializers/rack_attack.rb (already in template)
Rack::Attack.throttle('api/ip', limit: 100, period: 1.minute) do |req|
  req.ip
end
```

### 5. Monitoring

**Enable tunnel metrics:**

```bash
# Check metrics endpoint
curl http://localhost:41111/metrics

# Export to Prometheus/Grafana (optional)
```

**Monitor ActionCable:**

```ruby
# Log connection events
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      logger.info "User #{current_user.id} connected via #{request.ip}"
    end

    def disconnect
      logger.info "User #{current_user&.id} disconnected"
    end
  end
end
```

## Performance Considerations

### Cloudflare Plan Comparison

| Feature | Free | Pro | Business | Enterprise |
|---------|------|-----|----------|------------|
| **WebSocket Timeout** | 100s | 600s | 600s | Unlimited |
| **Concurrent Connections** | ~1,000 | ~5,000 | ~10,000 | Custom |
| **DDoS Protection** | Basic | Advanced | Advanced | Custom |
| **Support** | Community | Email | Priority | Dedicated |

### Scaling Guidelines

**< 1,000 concurrent users:**
- Free plan sufficient
- Single cloudflared instance
- Default configuration

**1,000-5,000 concurrent users:**
- Upgrade to Pro plan
- Run 2-3 cloudflared replicas
- Monitor connection metrics

**5,000-10,000 concurrent users:**
- Business plan recommended
- 3-5 cloudflared replicas
- Consider AnyCable for Rails

**10,000+ concurrent users:**
- Enterprise plan
- Multiple cloudflared replicas
- AnyCable + load balancing
- Dedicated support from Cloudflare

### Optimizing WebSocket Performance

1. **Enable compression:**
   ```yaml
   # cloudflared-config.yaml
   ingress:
     - hostname: api.yourdomain.com
       path: /cable
       service: http://web:3000
       originRequest:
         http2Origin: false
         disableChunkedEncoding: false  # Enable compression
   ```

2. **Reduce message size:**
   ```ruby
   # Send minimal data
   ActionCable.server.broadcast('notifications:123', {
     t: 'msg',  # Short keys
     d: { id: 1 }  # Only essential data
   })
   ```

3. **Batch messages:**
   ```ruby
   # Instead of 100 individual broadcasts
   messages = notifications.map { |n| { type: 'new', id: n.id } }
   ActionCable.server.broadcast('notifications:123', { batch: messages })
   ```

## Advanced Topics

### Multiple Environments

**Development:**
```yaml
# cloudflared-config.yaml
ingress:
  - hostname: api-dev.yourdomain.com
    path: /cable
    service: http://web:3000
```

**Staging:**
```yaml
ingress:
  - hostname: api-staging.yourdomain.com
    path: /cable
    service: http://web:3000
```

**Production:**
```yaml
ingress:
  - hostname: api.yourdomain.com
    path: /cable
    service: http://web:3000
```

### Custom Domains per Service

```yaml
ingress:
  # WebSocket for main app
  - hostname: ws.yourdomain.com
    service: http://web:3000
    originRequest:
      http2Origin: false

  # REST API
  - hostname: api.yourdomain.com
    service: http://web:3000

  # Admin panel
  - hostname: admin.yourdomain.com
    service: http://admin:4000

  - service: http_status:404
```

### Load Balancing Multiple Origins

```yaml
ingress:
  - hostname: api.yourdomain.com
    service: http_status:200
    originRequest:
      # Cloudflare Tunnel doesn't support origin load balancing
      # Use Cloudflare Load Balancer (separate product) instead
```

**Recommended:** Use multiple cloudflared replicas (same origin) instead.

### Metrics and Monitoring

**Prometheus scrape config:**

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'cloudflared'
    static_configs:
      - targets: ['cloudflared:41111']
```

**Key metrics:**
- `cloudflared_tunnel_total_requests` - Total requests
- `cloudflared_tunnel_response_by_code` - Response codes
- `cloudflared_tunnel_concurrent_requests_per_tunnel` - Active connections

### Using with Kubernetes

```yaml
# kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
          - tunnel
          - --config
          - /etc/cloudflared/config.yaml
          - --no-autoupdate
          - run
        volumeMounts:
          - name: config
            mountPath: /etc/cloudflared
          - name: credentials
            mountPath: /run/secrets
      volumes:
        - name: config
          configMap:
            name: cloudflared-config
        - name: credentials
          secret:
            secretName: cf-tunnel-credentials
```

## Summary

**Cloudflare Tunnel with ActionCable:**

✅ **Setup checklist:**
1. Create tunnel in Cloudflare Zero Trust
2. Save credentials JSON to `.secrets/cf_tunnel_token`
3. Configure `cloudflared-config.yaml` with tunnel ID
4. **Critical:** Set `http2Origin: false` for `/cable` path
5. Configure DNS CNAME record
6. Set `ACTION_CABLE_ALLOWED_ORIGINS` in Rails
7. Start with `docker compose --profile cloudflare up -d`

✅ **WebSocket best practices:**
- Use `http2Origin: false` for `/cable` route
- Set `keepAliveTimeout: 90s` for long connections
- Frontend auto-reconnect (built into ActionCable.js)
- Monitor connection health

✅ **Production ready:**
- Secure credential storage
- Proper origin validation
- Rate limiting (Cloudflare + Rack::Attack)
- Monitoring and alerting
- Auto-reconnection handling

**Need help?**
- Cloudflare Docs: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
- ActionCable Guides: https://guides.rubyonrails.org/action_cable_overview.html
- Template Docs: [README.md](../README.md)
