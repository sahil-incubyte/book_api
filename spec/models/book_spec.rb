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
end
