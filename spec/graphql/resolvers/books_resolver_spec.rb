# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::BooksResolver, type: :graphql do
  let(:query) do
    <<~GQL
      query {
        books {
          id
          title
          author
          price
        }
      }
    GQL
  end

  it "returns all books" do
    create(:book, title: "Dune")
    create(:book, title: "Neuromancer")

    result = execute_graphql(query)

    titles = result.dig("data", "books").map { |b| b["title"] }
    expect(titles).to contain_exactly("Dune", "Neuromancer")
  end

  it "returns an empty list when there are no books" do
    result = execute_graphql(query)

    expect(result.dig("data", "books")).to eq([])
  end
end
