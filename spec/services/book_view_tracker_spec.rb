# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookViewTracker do
  subject(:tracker) { described_class.new }

  # Keep the shared Redis keys clean so examples don't leak into each other.
  before do
    REDIS.with { |r| r.del(described_class::VIEWS_KEY, described_class::TRENDING_KEY) }
  end

  after do
    REDIS.with { |r| r.del(described_class::VIEWS_KEY, described_class::TRENDING_KEY) }
  end

  describe "#view_count" do
    it "starts at zero for an unseen book" do
      expect(tracker.view_count(1)).to eq(0)
    end

    it "counts each recorded view" do
      3.times { tracker.record_view(1) }
      expect(tracker.view_count(1)).to eq(3)
    end

    it "tracks books independently" do
      2.times { tracker.record_view(1) }
      tracker.record_view(2)

      expect(tracker.view_count(1)).to eq(2)
      expect(tracker.view_count(2)).to eq(1)
    end
  end

  describe "#trending" do
    it "returns books ordered by view count, highest first" do
      5.times { tracker.record_view(10) }
      9.times { tracker.record_view(20) }
      1.times { tracker.record_view(30) }

      expect(tracker.trending(limit: 2)).to eq(
        [ { book_id: 20, views: 9 }, { book_id: 10, views: 5 } ]
      )
    end

    it "returns an empty array when nothing has been viewed" do
      expect(tracker.trending).to eq([])
    end
  end

  describe "graceful degradation" do
    subject(:tracker) do
      described_class.new(redis_pool: ConnectionPool.new(size: 1) { Redis.new(url: "redis://localhost:6390/0") })
    end

    it "returns fallbacks instead of raising when Redis is unreachable" do
      expect { tracker.record_view(1) }.not_to raise_error
      expect(tracker.view_count(1)).to eq(0)
      expect(tracker.trending).to eq([])
    end
  end
end
