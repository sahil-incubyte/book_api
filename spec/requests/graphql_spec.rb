# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GraphQL endpoint", type: :request do
  def post_graphql(query, variables: {})
    post "/graphql", params: { query: query, variables: variables }, as: :json
    JSON.parse(response.body)
  end

  it "executes a query end-to-end through the controller" do
    book = create(:book, title: "Dune")

    body = post_graphql(<<~GQL, variables: { "id" => book.id.to_s })
      query($id: ID!) {
        book(id: $id) { id title }
      }
    GQL

    expect(response).to have_http_status(:ok)
    expect(body.dig("data", "book")).to eq("id" => book.id.to_s, "title" => "Dune")
  end

  it "executes a mutation end-to-end through the controller" do
    body = post_graphql(<<~GQL, variables: { "title" => "Dune", "author" => "Herbert", "price" => 20 })
      mutation($title: String!, $author: String!, $price: Int!) {
        createBook(input: { title: $title, author: $author, price: $price }) {
          book { id title }
          errors
        }
      }
    GQL

    expect(response).to have_http_status(:ok)
    payload = body.dig("data", "createBook")
    expect(payload["errors"]).to be_empty
    expect(payload.dig("book", "title")).to eq("Dune")
    expect(Book.count).to eq(1)
  end
end
