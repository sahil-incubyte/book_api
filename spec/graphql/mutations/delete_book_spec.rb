# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::DeleteBook, type: :graphql do
  let(:mutation) do
    <<~GQL
      mutation($id: ID!) {
        deleteBook(input: { id: $id }) {
          book {
            id
            title
          }
          errors
        }
      }
    GQL
  end

  it "deletes the book and returns it with no errors" do
    book = create(:book, title: "Dune")

    expect do
      @result = execute_graphql(mutation, variables: { "id" => book.id.to_s })
    end.to change(Book, :count).by(-1)

    payload = @result.dig("data", "deleteBook")
    expect(payload["errors"]).to be_empty
    expect(payload["book"]).to include("id" => book.id.to_s, "title" => "Dune")
    expect(Book.exists?(book.id)).to be(false)
  end

  it "returns a not-found error when the book does not exist" do
    result = execute_graphql(mutation, variables: { "id" => "999999" })

    payload = result.dig("data", "deleteBook")
    expect(payload["book"]).to be_nil
    expect(payload["errors"]).to eq([ "Book not found" ])
  end
end
