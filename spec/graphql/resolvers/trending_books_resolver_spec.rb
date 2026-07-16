# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::TrendingBooksResolver, type: :graphql do
  let(:query) do
    <<~GQL
      query {
        trendingBooks(limit: 2) {
          rank
          views
          book { id title }
        }
      }
    GQL
  end

  before do
    REDIS.with { |r| r.del(BookViewTracker::VIEWS_KEY, BookViewTracker::TRENDING_KEY) }
  end

  after do
    REDIS.with { |r| r.del(BookViewTracker::VIEWS_KEY, BookViewTracker::TRENDING_KEY) }
  end

  it "ranks books by view count, most viewed first" do
    popular = create(:book, title: "Popular")
    niche = create(:book, title: "Niche")
    tracker = BookViewTracker.new

    3.times { tracker.record_view(popular.id) }
    1.times { tracker.record_view(niche.id) }

    rows = execute_graphql(query).dig("data", "trendingBooks")

    expect(rows).to eq(
      [
        { "rank" => 1, "views" => 3, "book" => { "id" => popular.id.to_s, "title" => "Popular" } },
        { "rank" => 2, "views" => 1, "book" => { "id" => niche.id.to_s, "title" => "Niche" } }
      ]
    )
  end

  it "returns an empty list when no books have been viewed" do
    expect(execute_graphql(query).dig("data", "trendingBooks")).to eq([])
  end
end
