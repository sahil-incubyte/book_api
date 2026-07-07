# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::BookResolver, type: :graphql do
  let(:query) do
    <<~GQL
      query($id: ID!) {
        book(id: $id) {
          id
          title
        }
      }
    GQL
  end

  it "returns the book matching the given id" do
    book = create(:book, title: "Dune")

    result = execute_graphql(query, variables: { "id" => book.id.to_s })

    expect(result.dig("data", "book")).to eq("id" => book.id.to_s, "title" => "Dune")
  end

  it "surfaces a top-level GraphQL error when the book is not found" do
    result = execute_graphql(query, variables: { "id" => "999999" })

    expect(result.dig("data", "book")).to be_nil
    expect(result["errors"].map { |e| e["message"] })
      .to include("Book with id 999999 not found")
  end
end
