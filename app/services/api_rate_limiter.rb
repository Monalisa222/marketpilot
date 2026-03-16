class ApiRateLimiter
  LIMIT  = 40
  WINDOW = 60

  def self.redis
    @redis ||= Redis.new(url: "redis://localhost:6379/1")
  end

  def self.allow?(key)
    current = redis.incr(key)

    # Set expiry only when key is created
    redis.expire(key, WINDOW) if current == 1

    current <= LIMIT
  end
end
