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
    # How many recently-viewed book ids to keep per session.
    RECENT_LIMIT = 5

    def resolve(id:)
      book = Rails.cache.fetch("books/#{id}", skip_nil: true) { Book.find_by(id: id) }
      raise(GraphQL::ExecutionError, "Book with id #{id} not found") unless book

      # Count this view in Redis (hash + trending sorted set). A cache hit still
      # counts, so view tracking is independent of whether the DB was queried.
      BookViewTracker.new.record_view(book.id)

      # Remember this book in the visitor's Redis-backed session, most-recent
      # first, without duplicates.
      remember_recent_view(book.id)
      book
    end

    private

    def remember_recent_view(book_id)
      session = context[:session]
      return unless session

      recent = Array(session[:recently_viewed])
      recent.delete(book_id)
      recent.unshift(book_id)
      session[:recently_viewed] = recent.first(RECENT_LIMIT)
    end
  end
end
