# frozen_string_literal: true

# Elasticsearch integration for the Book model, kept in a concern so the model
# stays focused on domain rules and all the ES-specific knowledge lives in one
# place.
#
# What this wires up:
#   * `Elasticsearch::Model`            -> `.search`, `.import`, `__elasticsearch__`
#   * `Elasticsearch::Model::Callbacks` -> auto (re)index on create/update/destroy
#                                          (fired after_commit, so rolled-back
#                                          writes never touch the index)
#   * an explicit index mapping         -> we control the analyzers/field types
#   * `as_indexed_json`                 -> the exact document shape we send to ES,
#                                          including review data denormalized onto
#                                          the book so we can search/aggregate it
#                                          without a join ES can't do
#   * `es_search` / `es_facets`         -> the raw Query DSL (see below)
module Searchable
  extend ActiveSupport::Concern

  # Index-level configuration. One shard and zero replicas is right for a
  # single-node dev cluster — a replica would sit unassigned and leave the
  # cluster health permanently "yellow".
  INDEX_SETTINGS = {
    number_of_shards: 1,
    number_of_replicas: 0
  }.freeze

  # Whitelisted sort fields -> the ES field actually sorted on. `title` is
  # analyzed text (not directly sortable), so we sort on its `.keyword`
  # sub-field. Anything not in here falls back to relevance (`_score`).
  SORT_FIELDS = {
    title: "title.keyword",
    price: "price",
    created_at: "created_at"
  }.freeze

  # Whether writes should auto-sync to Elasticsearch. Off in the test env by
  # default so the full suite doesn't require a running cluster; flip it on with
  # ELASTICSEARCH_CALLBACKS=true when you want live indexing in tests. Referenced
  # by both the Book callbacks (below) and Review#reindex_book.
  def self.callbacks_enabled?
    !Rails.env.test? || ENV["ELASTICSEARCH_CALLBACKS"] == "true"
  end

  included do
    include Elasticsearch::Model
    # Auto (re)index on create/update/destroy — except when disabled for tests.
    include Elasticsearch::Model::Callbacks if Searchable.callbacks_enabled?

    # Environment-scoped name so dev/test/prod never share an index.
    index_name "books_#{Rails.env}"

    # deep_dup because elasticsearch-model mutates the settings hash while
    # assembling the index definition, and INDEX_SETTINGS is frozen.
    settings INDEX_SETTINGS.deep_dup do
      # `dynamic: false` -> ES ignores any field we didn't map, so the document
      # shape can't drift silently.
      mappings dynamic: false do
        # `text` fields are analyzed for full-text matching; the `keyword`
        # sub-field keeps the raw value for exact sorting/aggregation.
        indexes :title, type: :text, analyzer: :english,
                         fields: { keyword: { type: :keyword } }
        indexes :author, type: :text, analyzer: :english,
                          fields: { keyword: { type: :keyword } }
        indexes :price, type: :integer
        indexes :average_rating, type: :float
        indexes :reviews_count, type: :integer
        indexes :created_at, type: :date
      end
    end
  end

  # The document ES stores for this book. Review data is denormalized here so a
  # single index request can answer "average rating" questions — ES has no joins.
  def as_indexed_json(_options = {})
    {
      title: title,
      author: author,
      price: price,
      average_rating: reviews.average(:rating)&.to_f || 0.0,
      reviews_count: reviews.size,
      created_at: created_at
    }
  end

  class_methods do
    # Full-text search that returns ActiveRecord rows (ordered to match the ES
    # hits). When `term` is blank this degrades to "all books, filtered/sorted",
    # so the same path serves search-with-filters and filters-only.
    def es_search(term, min_price: nil, max_price: nil, sort_by: nil, sort_direction: nil)
      definition = {
        query: build_query(term, min_price, max_price),
        sort: build_sort(sort_by, sort_direction),
        # Books is a small dataset; pull the whole result set rather than page.
        size: 1_000
      }

      # `.records` re-hydrates the AR objects and (via the ActiveRecord adapter)
      # reorders them to match ES ranking, so relevance/sort order is preserved.
      __elasticsearch__.search(definition).records.to_a
    end

    # Aggregations for analytics. `size: 0` means "compute the buckets but don't
    # return any hits" — we only want the numbers. Filters are shared with
    # `es_search` so facets always describe the same result set as the search.
    def es_facets(term = nil, min_price: nil, max_price: nil)
      definition = {
        size: 0,
        query: build_query(term, min_price, max_price),
        aggs: {
          avg_price: { avg: { field: "price" } },
          avg_rating: { avg: { field: "average_rating" } },
          price_ranges: {
            range: {
              field: "price",
              ranges: [
                { key: "under_500", to: 500 },
                { key: "500_to_1000", from: 500, to: 1_000 },
                { key: "1000_plus", from: 1_000 }
              ]
            }
          },
          top_authors: { terms: { field: "author.keyword", size: 10 } }
        }
      }

      __elasticsearch__.search(definition).aggregations
    end

    private

    # A `bool` query: the full-text part goes in `must` (it contributes to the
    # relevance score); the price bounds go in `filter` (a yes/no match that
    # doesn't affect scoring and can be cached by ES).
    def build_query(term, min_price, max_price)
      trimmed = term.to_s.strip

      full_text =
        if trimmed.blank?
          { match_all: {} }
        else
          {
            multi_match: {
              query: trimmed,
              # `^2` boosts title matches above author matches; `fuzziness: AUTO`
              # tolerates small typos ("Tolkein" still finds "Tolkien").
              fields: [ "title^2", "author" ],
              fuzziness: "AUTO"
            }
          }
        end

      { bool: { must: full_text, filter: price_filter(min_price, max_price) } }
    end

    def price_filter(min_price, max_price)
      bounds = {}
      bounds[:gte] = min_price unless min_price.nil?
      bounds[:lte] = max_price unless max_price.nil?
      return [] if bounds.empty?

      [ { range: { price: bounds } } ]
    end

    # No explicit sort -> order by relevance. Otherwise sort on the whitelisted
    # field, defaulting an unspecified direction to descending (matching the
    # model's default sort behaviour).
    def build_sort(sort_by, sort_direction)
      return [ "_score" ] if sort_by.nil?

      field = SORT_FIELDS[sort_by]
      return [ "_score" ] if field.nil?

      direction = sort_direction == :asc ? "asc" : "desc"
      [ { field => direction } ]
    end
  end
end
