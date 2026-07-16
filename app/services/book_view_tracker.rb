# frozen_string_literal: true

# Tracks how often each book is viewed using two Redis data structures, each
# chosen for what it's good at:
#
#   - HASH  "book:views"     field = book id, value = lifetime view count.
#                            O(1) exact lookup of a single book's total.
#   - ZSET  "book:trending"  member = book id, score = view count.
#                            A sorted set keeps members ordered by score, so we
#                            can pull the top-N most-viewed books cheaply.
#
# Both are incremented together inside a MULTI transaction so they never drift
# apart. This is raw Redis (via the REDIS pool), not the Rails cache store.
class BookViewTracker
  VIEWS_KEY = "book:views"
  TRENDING_KEY = "book:trending"

  def initialize(redis_pool: REDIS)
    @redis_pool = redis_pool
  end

  # Record one view of a book: bump both its hash counter and its ZSET score.
  def record_view(book_id)
    with_redis(nil) do |redis|
      redis.multi do |tx|
        tx.hincrby(VIEWS_KEY, book_id, 1)
        tx.zincrby(TRENDING_KEY, 1, book_id)
      end
    end
  end

  # Lifetime view count for a single book (0 if never viewed).
  def view_count(book_id)
    with_redis(0) { |redis| redis.hget(VIEWS_KEY, book_id) }.to_i
  end

  # The most-viewed books, highest first:
  #   [{ book_id: 3, views: 42 }, { book_id: 1, views: 17 }, ...]
  def trending(limit: 10)
    pairs = with_redis([]) do |redis|
      redis.zrevrange(TRENDING_KEY, 0, limit - 1, with_scores: true)
    end
    pairs.map { |book_id, score| { book_id: book_id.to_i, views: score.to_i } }
  end

  private

  # View tracking is best-effort analytics, not core data: if Redis is down we
  # log and return a sensible fallback rather than failing the whole request.
  def with_redis(fallback)
    @redis_pool.with { |redis| yield redis }
  rescue Redis::BaseError, ConnectionPool::TimeoutError => e
    Rails.logger.warn("[BookViewTracker] Redis unavailable: #{e.class} #{e.message}")
    fallback
  end
end
