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

  let(:price_query) do
    <<~GQL
      query($search: String, $minPrice: Int, $maxPrice: Int) {
        books(search: $search, minPrice: $minPrice, maxPrice: $maxPrice) {
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

  describe "search argument" do
    let(:search_query) do
      <<~GQL
        query($search: String) {
          books(search: $search) {
            id
            title
            author
          }
        }
      GQL
    end

    # An active search term routes through Elasticsearch, so this example indexes
    # its data and needs a reachable cluster (see spec/support/elasticsearch.rb).
    it "returns only books matching the search term", :elasticsearch do
      dune = create(:book, title: "Dune", author: "Frank Herbert", price: 10)
      neuromancer = create(:book, title: "Neuromancer", author: "William Gibson", price: 10)
      index_books!(dune, neuromancer)

      result = execute_graphql(search_query, variables: { "search" => "dune" })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to contain_exactly("Dune")
    end

    it "returns the full list when the search term is blank" do
      create(:book, title: "Dune", author: "Frank Herbert", price: 10)
      create(:book, title: "Neuromancer", author: "William Gibson", price: 10)

      result = execute_graphql(search_query, variables: { "search" => "  " })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to contain_exactly("Dune", "Neuromancer")
    end

    it "returns the full list when the search argument is absent" do
      create(:book, title: "Dune", author: "Frank Herbert", price: 10)
      create(:book, title: "Neuromancer", author: "William Gibson", price: 10)

      result = execute_graphql(search_query)

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to contain_exactly("Dune", "Neuromancer")
    end
  end

  describe "price arguments" do
    it "returns only books priced at or above minPrice when only minPrice is given" do
      create(:book, title: "Cheap", author: "Anon", price: 10)
      create(:book, title: "Pricey", author: "Anon", price: 100)

      result = execute_graphql(price_query, variables: { "minPrice" => 50 })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to contain_exactly("Pricey")
    end

    it "returns only books priced at or below maxPrice when only maxPrice is given" do
      create(:book, title: "Cheap", author: "Anon", price: 10)
      create(:book, title: "Pricey", author: "Anon", price: 100)

      result = execute_graphql(price_query, variables: { "maxPrice" => 50 })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to contain_exactly("Cheap")
    end

    it "returns books within the inclusive range when both bounds are given" do
      create(:book, title: "Too Cheap", author: "Anon", price: 10)
      create(:book, title: "At Min", author: "Anon", price: 50)
      create(:book, title: "At Max", author: "Anon", price: 100)
      create(:book, title: "Too Pricey", author: "Anon", price: 150)

      result = execute_graphql(price_query, variables: { "minPrice" => 50, "maxPrice" => 100 })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to contain_exactly("At Min", "At Max")
    end

    it "returns an empty list when minPrice exceeds maxPrice" do
      create(:book, title: "Cheap", author: "Anon", price: 10)
      create(:book, title: "Pricey", author: "Anon", price: 100)

      result = execute_graphql(price_query, variables: { "minPrice" => 100, "maxPrice" => 10 })

      expect(result.dig("data", "books")).to eq([])
    end

    it "applies price bounds together with an active search via AND", :elasticsearch do
      deep_dive = create(:book, title: "Ruby Deep Dive", author: "Anon", price: 20)
      expensive = create(:book, title: "Ruby Expensive Edition", author: "Anon", price: 500)
      python = create(:book, title: "Python Basics", author: "Anon", price: 20)
      index_books!(deep_dive, expensive, python)

      result = execute_graphql(price_query, variables: { "search" => "ruby", "maxPrice" => 100 })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to contain_exactly("Ruby Deep Dive")
    end
  end

  describe "sort arguments" do
    let(:sort_query) do
      <<~GQL
        query($search: String, $minPrice: Int, $maxPrice: Int, $sortBy: BookSortField, $sortDirection: SortDirection) {
          books(search: $search, minPrice: $minPrice, maxPrice: $maxPrice, sortBy: $sortBy, sortDirection: $sortDirection) {
            id
            title
            author
            price
          }
        }
      GQL
    end

    it "orders results by title in the requested direction" do
      create(:book, title: "Beta", author: "Anon", price: 10)
      create(:book, title: "Alpha", author: "Anon", price: 10)
      create(:book, title: "Gamma", author: "Anon", price: 10)

      result = execute_graphql(sort_query, variables: { "sortBy" => "TITLE", "sortDirection" => "ASC" })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to eq([ "Alpha", "Beta", "Gamma" ])
    end

    it "orders results by price in the requested direction" do
      create(:book, title: "Mid", author: "Anon", price: 50)
      create(:book, title: "Cheap", author: "Anon", price: 10)
      create(:book, title: "Pricey", author: "Anon", price: 100)

      result = execute_graphql(sort_query, variables: { "sortBy" => "PRICE", "sortDirection" => "DESC" })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to eq([ "Pricey", "Mid", "Cheap" ])
    end

    it "orders results by creation time in the requested direction" do
      create(:book, title: "Newest", author: "Anon", price: 10, created_at: 1.day.ago)
      create(:book, title: "Oldest", author: "Anon", price: 10, created_at: 3.days.ago)
      create(:book, title: "Middle", author: "Anon", price: 10, created_at: 2.days.ago)

      result = execute_graphql(sort_query, variables: { "sortBy" => "CREATED_AT", "sortDirection" => "ASC" })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to eq([ "Oldest", "Middle", "Newest" ])
    end

    it "defaults to newest first (created_at DESC) when no sort arguments are given" do
      create(:book, title: "Newest", author: "Anon", price: 10, created_at: 1.day.ago)
      create(:book, title: "Oldest", author: "Anon", price: 10, created_at: 3.days.ago)
      create(:book, title: "Middle", author: "Anon", price: 10, created_at: 2.days.ago)

      result = execute_graphql(sort_query)

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to eq([ "Newest", "Middle", "Oldest" ])
    end

    it "rejects an invalid sortBy enum value via schema validation" do
      result = execute_graphql(<<~GQL)
        query {
          books(sortBy: BOGUS) {
            id
          }
        }
      GQL

      expect(result["errors"]).to be_present
      expect(result["data"]).to be_nil
    end

    it "rejects an invalid sortDirection enum value via schema validation" do
      result = execute_graphql(<<~GQL)
        query {
          books(sortBy: TITLE, sortDirection: SIDEWAYS) {
            id
          }
        }
      GQL

      expect(result["errors"]).to be_present
      expect(result["data"]).to be_nil
    end

    it "applies the sort to the set already narrowed by search and price (AND)", :elasticsearch do
      mid = create(:book, title: "Ruby Mid", author: "Anon", price: 50)
      cheap = create(:book, title: "Ruby Cheap", author: "Anon", price: 10)
      pricey = create(:book, title: "Ruby Pricey", author: "Anon", price: 500)
      python = create(:book, title: "Python Cheap", author: "Anon", price: 10)
      index_books!(mid, cheap, pricey, python)

      result = execute_graphql(
        sort_query,
        variables: { "search" => "ruby", "maxPrice" => 100, "sortBy" => "PRICE", "sortDirection" => "ASC" },
      )

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to eq([ "Ruby Cheap", "Ruby Mid" ])
    end
  end

  describe "cache behavior" do
    # The test environment uses :null_store; swap in a real in-memory store so we
    # can observe whether the "books/all" key is read from or written to.
    around do |example|
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original
    end

    let(:search_query) do
      <<~GQL
        query($search: String) {
          books(search: $search) {
            id
            title
            author
          }
        }
      GQL
    end

    let(:sort_query) do
      <<~GQL
        query($sortBy: BookSortField, $sortDirection: SortDirection) {
          books(sortBy: $sortBy, sortDirection: $sortDirection) {
            id
            title
            author
            price
          }
        }
      GQL
    end

    it "serves the default list from the cache when the sort is the default (CREATED_AT DESC)" do
      cached = Book.new(id: 999, title: "Cached Only", author: "Nobody", price: 1)
      Rails.cache.write("books/all", [ cached ])

      result = execute_graphql(sort_query, variables: { "sortBy" => "CREATED_AT", "sortDirection" => "DESC" })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to contain_exactly("Cached Only")
    end

    it "runs a non-default sort directly instead of reading the cached default list" do
      Rails.cache.write("books/all", [ Book.new(id: 999, title: "Cached Only", author: "Nobody", price: 1) ])
      create(:book, title: "Beta", author: "Anon", price: 10)
      create(:book, title: "Alpha", author: "Anon", price: 10)

      result = execute_graphql(sort_query, variables: { "sortBy" => "TITLE", "sortDirection" => "ASC" })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to eq([ "Alpha", "Beta" ])
    end

    it "does not populate the cache for a non-default sort with no search or price filter" do
      create(:book, title: "Beta", author: "Anon", price: 10)
      create(:book, title: "Alpha", author: "Anon", price: 10)

      execute_graphql(sort_query, variables: { "sortBy" => "TITLE", "sortDirection" => "ASC" })

      expect(Rails.cache.read("books/all")).to be_nil
    end

    it "orders the cached default list by created_at DESC (newest first)" do
      create(:book, title: "Newest", author: "Anon", price: 10, created_at: 1.day.ago)
      create(:book, title: "Oldest", author: "Anon", price: 10, created_at: 3.days.ago)
      create(:book, title: "Middle", author: "Anon", price: 10, created_at: 2.days.ago)

      result = execute_graphql(sort_query)

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to eq([ "Newest", "Middle", "Oldest" ])
      cached_titles = Rails.cache.read("books/all").map(&:title)
      expect(cached_titles).to eq([ "Newest", "Middle", "Oldest" ])
    end

    it "serves the default list from the cache when the search argument is absent" do
      cached = Book.new(id: 999, title: "Cached Only", author: "Nobody", price: 1)
      Rails.cache.write("books/all", [ cached ])

      result = execute_graphql(search_query)

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to contain_exactly("Cached Only")
    end

    it "serves the default list from the cache when the search term is blank" do
      cached = Book.new(id: 999, title: "Cached Only", author: "Nobody", price: 1)
      Rails.cache.write("books/all", [ cached ])

      result = execute_graphql(search_query, variables: { "search" => "  " })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to contain_exactly("Cached Only")
    end

    it "populates the cache with the default list when the search argument is absent" do
      create(:book, title: "Dune", author: "Frank Herbert", price: 10)

      execute_graphql(search_query)

      expect(Rails.cache.read("books/all")).not_to be_nil
    end

    it "does not read the cache when a search is active", :elasticsearch do
      Rails.cache.write("books/all", [ Book.new(id: 999, title: "Cached Only", author: "Nobody", price: 1) ])
      dune = create(:book, title: "Dune", author: "Frank Herbert", price: 10)
      index_books!(dune)

      result = execute_graphql(search_query, variables: { "search" => "dune" })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to contain_exactly("Dune")
    end

    it "does not populate the cache when a search is active", :elasticsearch do
      dune = create(:book, title: "Dune", author: "Frank Herbert", price: 10)
      index_books!(dune)

      execute_graphql(search_query, variables: { "search" => "dune" })

      expect(Rails.cache.read("books/all")).to be_nil
    end

    it "does not read the cache when a price bound is active" do
      Rails.cache.write("books/all", [ Book.new(id: 999, title: "Cached Only", author: "Nobody", price: 1) ])
      create(:book, title: "Dune", author: "Frank Herbert", price: 50)

      result = execute_graphql(price_query, variables: { "minPrice" => 10 })

      titles = result.dig("data", "books").map { |b| b["title"] }
      expect(titles).to contain_exactly("Dune")
    end

    it "does not populate the cache when a price bound is active" do
      create(:book, title: "Dune", author: "Frank Herbert", price: 50)

      execute_graphql(price_query, variables: { "minPrice" => 10 })

      expect(Rails.cache.read("books/all")).to be_nil
    end
  end
end
