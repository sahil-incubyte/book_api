# frozen_string_literal: true

module Types
  # One bucket of the price-range aggregation. `from`/`to` are the (inclusive
  # lower, exclusive upper) bounds ES used; either can be null for an open-ended
  # bucket ("under 500" has no `from`, "1000+" has no `to`).
  class PriceRangeBucketType < Types::BaseObject
    field :key, String, null: false
    field :from, Float, null: true
    field :to, Float, null: true
    field :count, Integer, null: false
  end

  # One bucket of the top-authors terms aggregation.
  class AuthorBucketType < Types::BaseObject
    field :author, String, null: false
    field :count, Integer, null: false
  end

  # Analytics computed by Elasticsearch aggregations over the current search /
  # filter selection — no book rows, just the rolled-up numbers.
  class BookSearchFacetsType < Types::BaseObject
    field :avg_price, Float, null: true, description: "Mean price across matching books."
    field :avg_rating, Float, null: true, description: "Mean review rating across matching books."
    field :price_ranges, [ Types::PriceRangeBucketType ], null: false,
                                                           description: "Book counts bucketed by price band."
    field :top_authors, [ Types::AuthorBucketType ], null: false,
                                                      description: "Most frequent authors among matching books."
  end
end
