# frozen_string_literal: true

module Mutations
  class CreateBook < BaseMutation
    argument :title, String, required: true
    argument :author, String, required: true
    argument :price, Integer, required: true

    field :book, Types::BookType, null: true
    field :errors, [ String ], null: false

    def resolve(title:, author:, price:)
      book = Book.new(title: title, author: author, price: price)
      book.save

      {
        book: book.persisted? ? book : nil,
        errors: book.errors.full_messages
      }
    end
  end
end
