class Review < ApplicationRecord
  belongs_to :book

  validates :reviewer, presence: true
  validates :rating, presence: true, numericality: { in: 1..5 }

  # The book's ES document denormalizes average_rating / reviews_count, so a
  # review change must re-index the parent book — the model's own callbacks only
  # fire on book writes, not on review writes.
  after_commit :reindex_book

  private

  def reindex_book
    return unless Searchable.callbacks_enabled?

    book&.__elasticsearch__&.index_document
  rescue Elastic::Transport::Transport::Error => e
    # Don't let an ES hiccup roll back / crash a successful review write; the
    # book can be re-synced later with `rake es:reindex`.
    Rails.logger.warn("[Searchable] failed to reindex book #{book_id}: #{e.message}")
  end
end
