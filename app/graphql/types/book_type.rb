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
  end
end
