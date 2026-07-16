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

  describe "Redis-backed sessions" do
    def view_book(book)
      post_graphql("query($id: ID!) { book(id: $id) { id } }", variables: { "id" => book.id.to_s })
    end

    def recently_viewed
      post_graphql("query { recentlyViewedBooks { id } }")
        .dig("data", "recentlyViewedBooks")
        .map { |b| b["id"] }
    end

    it "remembers recently-viewed books across requests via the session cookie" do
      dune = create(:book, title: "Dune")
      neuromancer = create(:book, title: "Neuromancer")

      # No session state yet.
      expect(recently_viewed).to eq([])

      # The integration session reuses the cookie set on the first response,
      # so state persists across these separate HTTP requests.
      view_book(dune)
      expect(recently_viewed).to eq([ dune.id.to_s ])

      view_book(neuromancer)
      expect(recently_viewed).to eq([ neuromancer.id.to_s, dune.id.to_s ])

      # Re-viewing moves a book back to the front without duplicating it.
      view_book(dune)
      expect(recently_viewed).to eq([ dune.id.to_s, neuromancer.id.to_s ])

      # A session cookie was actually issued to carry the session id.
      expect(response.headers["Set-Cookie"].to_s).to include("_book_api_session")
    end
  end
end
