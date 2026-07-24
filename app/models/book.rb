class Book < ApplicationRecord
  has_many :reviews, dependent: :destroy

  validates :title, presence: true
  validates :author, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Case-insensitive partial match on title OR author. A blank or whitespace-only
  # term means "no search", so the scope returns every book. User-typed ILIKE
  # wildcards (%, _, \) are escaped so they match literally.
  scope :search, ->(term) {
    trimmed = term.to_s.strip
    next all if trimmed.blank?

    pattern = "%#{sanitize_sql_like(trimmed)}%"
    where("title ILIKE :pattern OR author ILIKE :pattern", pattern: pattern)
  }

  # Inclusive integer price bounds. Each is applied independently, so callers can
  # supply a lower bound, an upper bound, or both. Combining an impossible range
  # (min greater than max) naturally yields zero rows.
  scope :price_at_least, ->(min) { where(price: min..) }
  scope :price_at_most, ->(max) { where(price: ..max) }

  # Whitelist the only columns and directions we allow ordering by. The keys are the
  # symbols produced by the GraphQL enums (Types::BookSortFieldEnum /
  # Types::SortDirectionEnum); the values are the safe literals we hand to `.order`.
  # This guarantees user input is never string-interpolated into the SQL.
  SORT_COLUMNS = { title: :title, price: :price, created_at: :created_at }.freeze
  SORT_DIRECTIONS = { asc: :asc, desc: :desc }.freeze
  DEFAULT_SORT_FIELD = :created_at
  DEFAULT_SORT_DIRECTION = :desc

  # Order by a whitelisted column/direction. `sorted_by(nil, nil)` yields
  # `created_at DESC` (newest first), which is also the cached default ordering so
  # the cached list and an explicit default-sort request always agree.
  scope :sorted_by, ->(field, direction) {
    column = SORT_COLUMNS.fetch(field || DEFAULT_SORT_FIELD)
    order_direction = SORT_DIRECTIONS.fetch(direction || DEFAULT_SORT_DIRECTION)
    order(column => order_direction)
  }

  # Keep the Redis cache consistent with the database. after_commit fires once
  # per create, update, and destroy — and only after the transaction actually
  # commits — so we never invalidate on a change that gets rolled back.
  #
  # This is explicit, write-through invalidation: whenever a book changes we
  # drop both the affected cache entries so the next read repopulates them.
  #   - "books/all"      -> the cached full list (see BooksResolver)
  #   - "books/#{id}"    -> the cached single book (see BookResolver)
  after_commit :invalidate_cache

  private

  def invalidate_cache
    Rails.cache.delete("books/all")
    Rails.cache.delete("books/#{id}")
  end
end
