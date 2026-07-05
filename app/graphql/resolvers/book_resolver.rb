module Resolvers
  class BookResolver < GraphQL::Schema::Resolver
    type Types::BookType, null: true

    argument :id, ID, required: true

    def resolve(id:)
      Book.find_by(id: id) ||
        raise(GraphQL::ExecutionError, "Book with id #{id} not found")
    end
  end
end
