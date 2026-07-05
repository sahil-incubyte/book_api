# frozen_string_literal: true

module Mutations
  class DeleteBook < BaseMutation
    argument :id, ID, required: true

    field :book, Types::BookType, null: true
    field :errors, [ String ], null: false

    def resolve(id:)
      book = Book.find_by(id: id)

      return { book: nil, errors: [ "Book not found" ] } if book.nil?

      if book.destroy
        { book: book, errors: [] }
      else
        { book: nil, errors: book.errors.full_messages }
      end
    end
  end
end
