# app/graphql/resolvers/books_resolver.rb

module Resolvers
  class BooksResolver < GraphQL::Schema::Resolver
    type [ Types::BookType ], null: false

    def resolve
      Book.all
    end
  end
end
