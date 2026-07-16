# frozen_string_literal: true

module Resolvers
  # Returns the most-viewed books, ranked by the Redis "book:trending" sorted
  # set. The ranking lives entirely in Redis; we only hit the database to
  # hydrate the book records for the top-N ids.
  class TrendingBooksResolver < GraphQL::Schema::Resolver
    type [ Types::TrendingBookType ], null: false

    argument :limit, Integer, required: false, default_value: 10

    def resolve(limit:)
      entries = BookViewTracker.new.trending(limit: limit)
      return [] if entries.empty?

      # One query for all the ids, then preserve Redis' ranking order.
      books_by_id = Book.where(id: entries.map { |e| e[:book_id] }).index_by(&:id)

      entries.filter_map.with_index(1) do |entry, rank|
        book = books_by_id[entry[:book_id]]
        next unless book # skip ids that have since been deleted from the DB

        { rank: rank, views: entry[:views], book: book }
      end
    end
  end
end
