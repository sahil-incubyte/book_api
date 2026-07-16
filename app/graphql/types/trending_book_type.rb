# frozen_string_literal: true

module Types
  # One entry in the trending leaderboard: a book paired with the view count
  # that earned it its rank (rank 1 = most viewed).
  class TrendingBookType < Types::BaseObject
    field :rank, Integer, null: false
    field :views, Integer, null: false
    field :book, Types::BookType, null: false
  end
end
