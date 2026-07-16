class Book < ApplicationRecord
  validates :title, presence: true
  validates :author, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

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
