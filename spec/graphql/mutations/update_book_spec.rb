# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::UpdateBook, type: :graphql do
  let(:mutation) do
    <<~GQL
      mutation($id: ID!, $title: String, $price: Int) {
        updateBook(input: { id: $id, title: $title, price: $price }) {
          book {
            id
            title
            author
            price
          }
          errors
        }
      }
    GQL
  end

  it "updates only the supplied fields and leaves others untouched" do
    book = create(:book, title: "Old", author: "Herbert", price: 10)

    result = execute_graphql(mutation, variables: { "id" => book.id.to_s, "price" => 99 })

    payload = result.dig("data", "updateBook")
    expect(payload["errors"]).to be_empty
    expect(payload["book"]).to include("title" => "Old", "author" => "Herbert", "price" => 99)
    expect(book.reload.price).to eq(99)
  end

  it "returns a not-found error when the book does not exist" do
    result = execute_graphql(mutation, variables: { "id" => "999999", "price" => 5 })

    payload = result.dig("data", "updateBook")
    expect(payload["book"]).to be_nil
    expect(payload["errors"]).to eq([ "Book not found" ])
  end

  it "returns validation errors when the update is invalid" do
    book = create(:book, title: "Valid")

    result = execute_graphql(mutation, variables: { "id" => book.id.to_s, "title" => "" })

    payload = result.dig("data", "updateBook")
    expect(payload["book"]).to be_nil
    expect(payload["errors"]).to include("Title can't be blank")
    expect(book.reload.title).to eq("Valid")
  end
end
