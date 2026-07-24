# frozen_string_literal: true

require "rails_helper"

RSpec.describe Book, type: :model do
  it "is valid with a title, author and non-negative price" do
    expect(build(:book)).to be_valid
  end

  describe "validations" do
    it "is invalid without a title" do
      book = build(:book, title: nil)
      expect(book).not_to be_valid
      expect(book.errors[:title]).to include("can't be blank")
    end

    it "is invalid without an author" do
      book = build(:book, author: nil)
      expect(book).not_to be_valid
      expect(book.errors[:author]).to include("can't be blank")
    end

    it "is invalid without a price" do
      book = build(:book, price: nil)
      expect(book).not_to be_valid
      expect(book.errors[:price]).to include("can't be blank")
    end

    it "is invalid with a negative price" do
      book = build(:book, price: -1)
      expect(book).not_to be_valid
      expect(book.errors[:price]).to include("must be greater than or equal to 0")
    end

    it "accepts a price of zero" do
      expect(build(:book, price: 0)).to be_valid
    end
  end

  describe ".search scope" do
    it "matches books whose title contains the term (case-insensitive, partial)" do
      match = create(:book, title: "The Great Gatsby", author: "Fitzgerald", price: 10)
      create(:book, title: "Moby Dick", author: "Melville", price: 10)

      expect(Book.search("great")).to contain_exactly(match)
    end

    it "matches books whose author contains the term (case-insensitive, partial)" do
      match = create(:book, title: "Neuromancer", author: "William Gibson", price: 10)
      create(:book, title: "Dune", author: "Frank Herbert", price: 10)

      expect(Book.search("gibson")).to contain_exactly(match)
    end

    it "matches on either title or author in a single search" do
      by_title = create(:book, title: "Ruby Under a Microscope", author: "Pat Shaughnessy", price: 10)
      by_author = create(:book, title: "The Well-Grounded Rubyist", author: "David Ruby", price: 10)
      create(:book, title: "Clean Code", author: "Robert Martin", price: 10)

      expect(Book.search("ruby")).to contain_exactly(by_title, by_author)
    end

    it "returns an empty relation when nothing matches" do
      create(:book, title: "Dune", author: "Frank Herbert", price: 10)

      expect(Book.search("nonexistent")).to be_empty
    end

    it "returns all books when the term is blank" do
      create(:book, title: "Dune", author: "Frank Herbert", price: 10)
      create(:book, title: "Neuromancer", author: "William Gibson", price: 10)

      expect(Book.search("")).to match_array(Book.all)
    end

    it "returns all books when the term is whitespace-only" do
      create(:book, title: "Dune", author: "Frank Herbert", price: 10)
      create(:book, title: "Neuromancer", author: "William Gibson", price: 10)

      expect(Book.search("   ")).to match_array(Book.all)
    end

    it "treats a literal % as text, not a wildcard" do
      literal = create(:book, title: "Save 50% today", author: "Anon", price: 10)
      create(:book, title: "5000 leagues", author: "Anon", price: 10)

      expect(Book.search("50%")).to contain_exactly(literal)
    end

    it "treats a literal _ as text, not a single-character wildcard" do
      literal = create(:book, title: "chapter_one", author: "Anon", price: 10)
      create(:book, title: "chapterXone", author: "Anon", price: 10)

      expect(Book.search("chapter_one")).to contain_exactly(literal)
    end

    it "treats a literal backslash as text, not an escape character" do
      literal = create(:book, title: 'path\to\file', author: "Anon", price: 10)
      create(:book, title: "path to file", author: "Anon", price: 10)

      expect(Book.search('path\to')).to contain_exactly(literal)
    end
  end

  describe ".price_at_least scope" do
    it "returns only books priced at or above the minimum, inclusive of the boundary" do
      below = create(:book, title: "Below", author: "Anon", price: 9)
      at_boundary = create(:book, title: "At", author: "Anon", price: 10)
      above = create(:book, title: "Above", author: "Anon", price: 11)

      result = Book.price_at_least(10)

      expect(result).to contain_exactly(at_boundary, above)
      expect(result).not_to include(below)
    end
  end

  describe ".price_at_most scope" do
    it "returns only books priced at or below the maximum, inclusive of the boundary" do
      below = create(:book, title: "Below", author: "Anon", price: 9)
      at_boundary = create(:book, title: "At", author: "Anon", price: 10)
      above = create(:book, title: "Above", author: "Anon", price: 11)

      result = Book.price_at_most(10)

      expect(result).to contain_exactly(below, at_boundary)
      expect(result).not_to include(above)
    end
  end

  describe ".sorted_by scope" do
    it "orders by title ascending" do
      beta = create(:book, title: "Beta", author: "Anon", price: 10)
      alpha = create(:book, title: "Alpha", author: "Anon", price: 10)
      gamma = create(:book, title: "Gamma", author: "Anon", price: 10)

      expect(Book.sorted_by(:title, :asc).to_a).to eq([ alpha, beta, gamma ])
    end

    it "orders by title descending" do
      beta = create(:book, title: "Beta", author: "Anon", price: 10)
      alpha = create(:book, title: "Alpha", author: "Anon", price: 10)
      gamma = create(:book, title: "Gamma", author: "Anon", price: 10)

      expect(Book.sorted_by(:title, :desc).to_a).to eq([ gamma, beta, alpha ])
    end

    it "orders by price ascending" do
      mid = create(:book, title: "Mid", author: "Anon", price: 50)
      cheap = create(:book, title: "Cheap", author: "Anon", price: 10)
      pricey = create(:book, title: "Pricey", author: "Anon", price: 100)

      expect(Book.sorted_by(:price, :asc).to_a).to eq([ cheap, mid, pricey ])
    end

    it "orders by price descending" do
      mid = create(:book, title: "Mid", author: "Anon", price: 50)
      cheap = create(:book, title: "Cheap", author: "Anon", price: 10)
      pricey = create(:book, title: "Pricey", author: "Anon", price: 100)

      expect(Book.sorted_by(:price, :desc).to_a).to eq([ pricey, mid, cheap ])
    end

    it "orders by created_at ascending (oldest first)" do
      newest = create(:book, title: "Newest", author: "Anon", price: 10, created_at: 1.day.ago)
      oldest = create(:book, title: "Oldest", author: "Anon", price: 10, created_at: 3.days.ago)
      middle = create(:book, title: "Middle", author: "Anon", price: 10, created_at: 2.days.ago)

      expect(Book.sorted_by(:created_at, :asc).to_a).to eq([ oldest, middle, newest ])
    end

    it "orders by created_at descending (newest first)" do
      newest = create(:book, title: "Newest", author: "Anon", price: 10, created_at: 1.day.ago)
      oldest = create(:book, title: "Oldest", author: "Anon", price: 10, created_at: 3.days.ago)
      middle = create(:book, title: "Middle", author: "Anon", price: 10, created_at: 2.days.ago)

      expect(Book.sorted_by(:created_at, :desc).to_a).to eq([ newest, middle, oldest ])
    end

    it "defaults to created_at descending (newest first) when field and direction are nil" do
      newest = create(:book, title: "Newest", author: "Anon", price: 10, created_at: 1.day.ago)
      oldest = create(:book, title: "Oldest", author: "Anon", price: 10, created_at: 3.days.ago)
      middle = create(:book, title: "Middle", author: "Anon", price: 10, created_at: 2.days.ago)

      expect(Book.sorted_by(nil, nil).to_a).to eq([ newest, middle, oldest ])
    end
  end

  describe "cache invalidation" do
    # The test environment uses :null_store, so swap in a real in-memory store
    # for these examples to observe entries actually being dropped.
    around do |example|
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original
    end

    it "clears the cached list when a book is created" do
      Rails.cache.write("books/all", [ "stale" ])

      create(:book)

      expect(Rails.cache.read("books/all")).to be_nil
    end

    it "clears both the list and the per-id entry when a book is updated" do
      book = create(:book)
      Rails.cache.write("books/all", [ "stale" ])
      Rails.cache.write("books/#{book.id}", "stale")

      book.update!(title: "New Title")

      expect(Rails.cache.read("books/all")).to be_nil
      expect(Rails.cache.read("books/#{book.id}")).to be_nil
    end

    it "clears both the list and the per-id entry when a book is destroyed" do
      book = create(:book)
      Rails.cache.write("books/all", [ "stale" ])
      Rails.cache.write("books/#{book.id}", "stale")

      book.destroy!

      expect(Rails.cache.read("books/all")).to be_nil
      expect(Rails.cache.read("books/#{book.id}")).to be_nil
    end
  end
end
