# app/graphql/resolvers/books_resolver.rb

module Resolvers
  class BooksResolver < GraphQL::Schema::Resolver
    type [ Types::BookType ], null: false

    argument :search, String, required: false
    argument :min_price, Integer, required: false
    argument :max_price, Integer, required: false
    argument :sort_by, Types::BookSortFieldEnum, required: false
    argument :sort_direction, Types::SortDirectionEnum, required: false

    # We cache only the unfiltered default list under a single fixed key so repeat
    # reads skip the database query. The cache is invalidated only for the default
    # list and per-book entries whenever a book changes (see the Book model), so any
    # request whose result differs from that default MUST bypass the cache entirely.
    # Introducing per-filter cache keys would leave them stale.
    #
    # The cached default list is ordered `created_at DESC` (via Book.sorted_by(nil,
    # nil)) so it matches the default sort. That lets us serve two cases from cache:
    # a request with no filters and no sort, and a request that explicitly asks for
    # the default sort (created_at DESC) — both equal the cached ordering.
    #
    # A NON-DEFAULT sort (e.g. TITLE/ASC, or CREATED_AT/ASC) would produce a
    # different ordering than the cached list, so it must run the query directly even
    # when no search/price filter is present. `filters_present?` therefore stays
    # scoped to search + price only; the cache-bypass decision additionally accounts
    # for a non-default sort via `default_sort?`.
    #
    # We materialise the relation with `to_a` because a lazy ActiveRecord relation
    # can't be meaningfully serialised into the cache.
    CACHE_KEY = "books/all"

    def resolve(search: nil, min_price: nil, max_price: nil, sort_by: nil, sort_direction: nil)
      if serve_from_cache?(search, min_price, max_price, sort_by, sort_direction)
        return Rails.cache.fetch(CACHE_KEY) { Book.sorted_by(nil, nil).to_a }
      end

      queried_books(search, min_price, max_price, sort_by, sort_direction)
    end

    private

    def queried_books(search, min_price, max_price, sort_by, sort_direction)
      scope = Book.search(search)
      scope = scope.price_at_least(min_price) unless min_price.nil?
      scope = scope.price_at_most(max_price) unless max_price.nil?
      scope.sorted_by(sort_by, sort_direction).to_a
    end

    def serve_from_cache?(search, min_price, max_price, sort_by, sort_direction)
      !filters_present?(search, min_price, max_price) &&
        default_sort?(sort_by, sort_direction)
    end

    def filters_present?(search, min_price, max_price)
      search.to_s.strip.present? || !min_price.nil? || !max_price.nil?
    end

    def default_sort?(sort_by, sort_direction)
      (sort_by.nil? || sort_by == Book::DEFAULT_SORT_FIELD) &&
        (sort_direction.nil? || sort_direction == Book::DEFAULT_SORT_DIRECTION)
    end
  end
end
