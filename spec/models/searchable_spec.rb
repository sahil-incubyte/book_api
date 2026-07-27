# frozen_string_literal: true

require "rails_helper"

# Integration specs for the Elasticsearch-backed search. Tagged `:elasticsearch`
# so they run against the real cluster (and skip when none is reachable).
RSpec.describe Searchable, :elasticsearch do
  describe ".es_search" do
    it "matches on the title with a full-text query" do
      match = create(:book, title: "The Ruby Programming Language", author: "Matz")
      _other = create(:book, title: "Cooking with Fire", author: "Anon")
      index_books!(match, _other)

      expect(Book.es_search("ruby")).to contain_exactly(match)
    end

    it "matches on the author too" do
      match = create(:book, title: "Neuromancer", author: "William Gibson")
      _other = create(:book, title: "Dune", author: "Frank Herbert")
      index_books!(match, _other)

      expect(Book.es_search("gibson")).to contain_exactly(match)
    end

    it "tolerates small typos via fuzziness" do
      match = create(:book, title: "The Hobbit", author: "Tolkien")
      index_books!(match)

      expect(Book.es_search("Tolkein")).to contain_exactly(match)
    end

    it "ranks the stronger title match ahead of a weaker one" do
      strong = create(:book, title: "Elasticsearch: The Definitive Guide", author: "Clinton Gormley")
      weak   = create(:book, title: "Databases", author: "Search Guru")
      index_books!(strong, weak)

      expect(Book.es_search("elasticsearch").first).to eq(strong)
    end

    it "applies price bounds as a filter alongside the text query" do
      cheap = create(:book, title: "Ruby Basics", author: "A", price: 200)
      pricey = create(:book, title: "Ruby Mastery", author: "B", price: 900)
      index_books!(cheap, pricey)

      expect(Book.es_search("ruby", max_price: 500)).to contain_exactly(cheap)
      expect(Book.es_search("ruby", min_price: 500)).to contain_exactly(pricey)
    end

    it "honours an explicit sort over relevance" do
      b1 = create(:book, title: "Ruby One", author: "A", price: 300)
      b2 = create(:book, title: "Ruby Two", author: "B", price: 100)
      index_books!(b1, b2)

      result = Book.es_search("ruby", sort_by: :price, sort_direction: :asc)
      expect(result).to eq([ b2, b1 ])
    end

    it "returns every book (filtered) when the term is blank" do
      a = create(:book, price: 100)
      b = create(:book, price: 900)
      index_books!(a, b)

      expect(Book.es_search("")).to match_array([ a, b ])
      expect(Book.es_search("", max_price: 500)).to contain_exactly(a)
    end
  end

  describe ".es_facets" do
    it "aggregates price and rating analytics over the matching books" do
      cheap = create(:book, title: "Ruby A", author: "Matz", price: 100)
      mid   = create(:book, title: "Ruby B", author: "Matz", price: 700)
      pricey = create(:book, title: "Ruby C", author: "DHH", price: 1_500)
      cheap.reviews.create!(reviewer: "r", rating: 4)
      cheap.reviews.create!(reviewer: "r2", rating: 2)
      index_books!(cheap, mid, pricey)

      facets = Book.es_facets("ruby")

      expect(facets.dig("avg_price", "value")).to be_within(0.01).of((100 + 700 + 1_500) / 3.0)
      # cheap has ratings [4, 2] -> 3.0; mid/pricey have none -> 0.0. Mean = 1.0.
      expect(facets.dig("avg_rating", "value")).to be_within(0.01).of(1.0)

      buckets = facets.dig("price_ranges", "buckets").index_by { |b| b["key"] }
      expect(buckets["under_500"]["doc_count"]).to eq(1)
      expect(buckets["500_to_1000"]["doc_count"]).to eq(1)
      expect(buckets["1000_plus"]["doc_count"]).to eq(1)

      authors = facets.dig("top_authors", "buckets").index_by { |b| b["key"] }
      expect(authors["Matz"]["doc_count"]).to eq(2)
      expect(authors["DHH"]["doc_count"]).to eq(1)
    end
  end
end
