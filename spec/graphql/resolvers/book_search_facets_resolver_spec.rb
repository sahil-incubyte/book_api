# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::BookSearchFacetsResolver, :elasticsearch, type: :graphql do
  let(:query) do
    <<~GQL
      query($search: String, $minPrice: Int, $maxPrice: Int) {
        bookSearchFacets(search: $search, minPrice: $minPrice, maxPrice: $maxPrice) {
          avgPrice
          avgRating
          priceRanges { key from to count }
          topAuthors { author count }
        }
      }
    GQL
  end

  it "returns aggregation analytics for the matching books" do
    cheap = create(:book, title: "Ruby A", author: "Matz", price: 100)
    mid = create(:book, title: "Ruby B", author: "Matz", price: 700)
    pricey = create(:book, title: "Ruby C", author: "DHH", price: 1_500)
    cheap.reviews.create!(reviewer: "r", rating: 5)
    index_books!(cheap, mid, pricey)

    facets = execute_graphql(query, variables: { "search" => "ruby" }).dig("data", "bookSearchFacets")

    expect(facets["avgPrice"]).to be_within(0.01).of((100 + 700 + 1_500) / 3.0)

    counts = facets["priceRanges"].to_h { |b| [ b["key"], b["count"] ] }
    expect(counts).to eq("under_500" => 1, "500_to_1000" => 1, "1000_plus" => 1)

    authors = facets["topAuthors"].to_h { |b| [ b["author"], b["count"] ] }
    expect(authors).to eq("Matz" => 2, "DHH" => 1)
  end

  it "narrows the analytics with a price filter" do
    create_and_index_cheap = create(:book, title: "Ruby Cheap", author: "Matz", price: 100)
    create_and_index_pricey = create(:book, title: "Ruby Pricey", author: "DHH", price: 1_500)
    index_books!(create_and_index_cheap, create_and_index_pricey)

    facets = execute_graphql(query, variables: { "search" => "ruby", "maxPrice" => 500 })
             .dig("data", "bookSearchFacets")

    expect(facets["avgPrice"]).to eq(100.0)
    expect(facets["topAuthors"].to_h { |b| [ b["author"], b["count"] ] }).to eq("Matz" => 1)
  end
end
