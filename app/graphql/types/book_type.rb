# frozen_string_literal: true

module Types
  class BookType < Types::BaseObject
    field :id, ID, null: false
    field :title, String
    field :author, String
    field :price, Integer
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Lifetime view count, read from the Redis "book:views" hash.
    field :view_count, Integer, null: false

    def view_count
      BookViewTracker.new.view_count(object.id)
    end

    # Reviews for this book.
    #
    # NOTE (SQL N+1): `object.reviews` runs `SELECT * FROM reviews WHERE book_id = ?`
    # the first time it's touched for a given book. When a list field resolves
    # `reviews` for every book in a collection (e.g. `books { reviews { rating } }`),
    # that query fires once PER BOOK: 1 query to load N books + N queries for their
    # reviews = the classic N+1. Watch the Rails log during such a query and you'll
    # see one "SELECT ... FROM reviews WHERE book_id = $1" line per book.
    #
    # The fix (left undone on purpose) is to eager-load: have the list resolver call
    # `Book.includes(:reviews)`, which collapses the N review queries into one
    # `WHERE book_id IN (...)`. A GraphQL Dataloader would achieve the same batching.
    field :reviews, [ Types::ReviewType ], null: false

    def reviews
      object.reviews
    end
  end
end
