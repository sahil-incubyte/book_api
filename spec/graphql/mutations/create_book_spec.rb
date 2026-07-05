# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::CreateBook, type: :graphql do
  let(:mutation) do
    <<~GQL
      mutation($title: String!, $author: String!, $price: Int!) {
        createBook(input: { title: $title, author: $author, price: $price }) {
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

  it "creates a book and returns it with no errors" do
    expect do
      @result = execute_graphql(
        mutation,
        variables: { "title" => "Dune", "author" => "Herbert", "price" => 20 }
      )
    end.to change(Book, :count).by(1)

    payload = @result.dig("data", "createBook")
    expect(payload["errors"]).to be_empty
    expect(payload["book"]).to include("title" => "Dune", "author" => "Herbert", "price" => 20)
  end

  it "returns validation errors and creates nothing when input is invalid" do
    expect do
      @result = execute_graphql(
        mutation,
        variables: { "title" => "", "author" => "Herbert", "price" => 20 }
      )
    end.not_to change(Book, :count)

    payload = @result.dig("data", "createBook")
    expect(payload["book"]).to be_nil
    expect(payload["errors"]).to include("Title can't be blank")
  end
end
