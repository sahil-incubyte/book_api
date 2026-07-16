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
