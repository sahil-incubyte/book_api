# app/graphql/resolvers/books_resolver.rb

module Resolvers
  class BooksResolver < GraphQL::Schema::Resolver
    type [ Types::BookType ], null: false

    # The full book list is cached under a single fixed key so repeat reads
    # skip the database query. The cache is explicitly invalidated whenever a
    # book is created, updated, or destroyed (see the Book model, Step 4).
    #
    # We materialise the relation with `to_a` because a lazy ActiveRecord
    # relation can't be meaningfully serialised into the cache.
    CACHE_KEY = "books/all"

    def resolve
      Rails.cache.fetch(CACHE_KEY) { Book.all.to_a }
    end
  end
end
