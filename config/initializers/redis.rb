# frozen_string_literal: true

require "redis"
require "connection_pool"

# A process-wide, thread-safe pool of Redis connections used for raw Redis
# data-structure work (view counts, trending leaderboard) — separate from the
# Rails cache store, which manages its own connections.
#
# A bare Redis client is NOT safe to share across Puma threads, so we hand each
# thread its own connection from the pool via `REDIS.with { |r| ... }`.
REDIS = ConnectionPool.new(
  size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i,
  timeout: 5
) do
  Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
end
