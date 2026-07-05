# frozen_string_literal: true

module Mutations
  class UpdateBook < BaseMutation
    argument :id, ID, required: true
    argument :title, String, required: false
    argument :author, String, required: false
    argument :price, Integer, required: false

    field :book, Types::BookType, null: true
    field :errors, [ String ], null: false

    def resolve(id:, **attributes)
      book = Book.find_by(id: id)

      return { book: nil, errors: [ "Book not found" ] } if book.nil?

      book.update(attributes.compact)

      {
        book: book.errors.empty? ? book : nil,
        errors: book.errors.full_messages
      }
    end
  end
end
