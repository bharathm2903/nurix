# Rate limiting configuration using Rack::Attack
# Enforces per-user rate limits for job submission

class Rack::Attack
  # Configure cache store (use Redis in production, memory store for development)
  if Rails.env.production?
    self.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
  else
    self.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  # Enable logging
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    Rails.logger.warn("[Rack::Attack] #{req.env['rack.attack.match_type']} - #{req.ip} - #{req.path}")
  end

  # Throttle job submissions: max 10 jobs per minute per user
  throttle('api/jobs/create', limit: 10, period: 1.minute) do |req|
    if req.path == '/api/jobs' && req.post?
      # Extract user_id from header or params
      user_id = req.env['HTTP_X_USER_ID'] || req.params['user_id']
      user_id.present? ? "user:#{user_id}" : req.ip
    end
  end

  # Throttle API requests in general: max 100 requests per minute per IP
  throttle('api/req/ip', limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # Block suspicious requests
  blocklist('block bad actors') do |req|
    # Block requests from known bad IPs (configure as needed)
    # Blocklist::BLOCKED_IPS.include?(req.ip)
    false # Disabled for now
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |env|
    match_data = env['rack.attack.match_data']
    now = match_data[:epoch_time]
    
    headers = {
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s,
      'Content-Type' => 'application/json'
    }

    body = {
      error: 'Rate limit exceeded',
      message: 'Too many requests. Please try again later.',
      retry_after: (match_data[:period] - now % match_data[:period]).to_i
    }.to_json

    [429, headers, [body]]
  end
end

