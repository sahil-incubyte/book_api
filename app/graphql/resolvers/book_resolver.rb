module Resolvers
  class BookResolver < GraphQL::Schema::Resolver
    type Types::BookType, null: true

    argument :id, ID, required: true

    # Cache a single book under a per-id key. On a cache hit we skip the DB
    # query entirely. The key is explicitly invalidated when that book is
    # updated or destroyed (see the Book model, Step 4).
    #
    # We only cache found books: a "not found" is raised as an error and never
    # written to the cache, so a newly-created book isn't shadowed by a miss.
    def resolve(id:)
      book = Rails.cache.fetch("books/#{id}", skip_nil: true) { Book.find_by(id: id) }
      raise(GraphQL::ExecutionError, "Book with id #{id} not found") unless book

      # Count this view in Redis (hash + trending sorted set). A cache hit still
      # counts, so view tracking is independent of whether the DB was queried.
      BookViewTracker.new.record_view(book.id)
      book
    end
  end
end
