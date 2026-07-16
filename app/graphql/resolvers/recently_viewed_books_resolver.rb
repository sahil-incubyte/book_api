# frozen_string_literal: true

module Resolvers
  # Returns the books this visitor has viewed, most-recent first. The list of
  # ids lives in the Redis-backed session (see BookResolver), so it is scoped to
  # the individual visitor's cookie rather than shared globally.
  class RecentlyViewedBooksResolver < GraphQL::Schema::Resolver
    type [ Types::BookType ], null: false

    def resolve
      ids = Array(context[:session]&.[](:recently_viewed))
      return [] if ids.empty?

      # One query for all ids, then restore the session's recency order.
      books_by_id = Book.where(id: ids).index_by(&:id)
      ids.filter_map { |id| books_by_id[id] }
    end
  end
end
