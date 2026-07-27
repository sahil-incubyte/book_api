# frozen_string_literal: true

module Resolvers
  # Runs an aggregation-only Elasticsearch query (size: 0) over the same
  # search/price selection the `books` field accepts, and reshapes the raw
  # aggregation buckets into the GraphQL facets type. Useful for building a
  # "faceted search" sidebar or an analytics panel.
  class BookSearchFacetsResolver < GraphQL::Schema::Resolver
    type Types::BookSearchFacetsType, null: false

    argument :search, String, required: false
    argument :min_price, Integer, required: false
    argument :max_price, Integer, required: false

    def resolve(search: nil, min_price: nil, max_price: nil)
      aggs = Book.es_facets(search, min_price: min_price, max_price: max_price)

      {
        avg_price: aggs.dig("avg_price", "value"),
        avg_rating: aggs.dig("avg_rating", "value"),
        price_ranges: price_range_buckets(aggs),
        top_authors: author_buckets(aggs)
      }
    end

    private

    def price_range_buckets(aggs)
      aggs.dig("price_ranges", "buckets").to_a.map do |bucket|
        {
          key: bucket["key"],
          from: bucket["from"],
          to: bucket["to"],
          count: bucket["doc_count"]
        }
      end
    end

    def author_buckets(aggs)
      aggs.dig("top_authors", "buckets").to_a.map do |bucket|
        { author: bucket["key"], count: bucket["doc_count"] }
      end
    end
  end
end
