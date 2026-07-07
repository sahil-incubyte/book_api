# frozen_string_literal: true

require "rails_helper"

RSpec.describe OpenLibraryService do
  subject(:service) { described_class.new }

  # Match on method + path so hand-recorded cassettes aren't sensitive to
  # query-string encoding differences. Each cassette holds a single interaction.
  let(:cassette_options) { { match_requests_on: %i[method path] } }

  describe "#fetch_book" do
    it "returns book details for a known ISBN" do
      result = VCR.use_cassette("open_library/known_isbn", cassette_options) do
        service.fetch_book("0451526538")
      end

      expect(result[:title]).to eq("The Great Gatsby")
      expect(result[:authors]).to eq([ "F. Scott Fitzgerald" ])
      expect(result[:publish_date]).to eq("2004")
    end

    it "returns nil for an unknown ISBN" do
      result = VCR.use_cassette("open_library/unknown_isbn", cassette_options) do
        service.fetch_book("0000000000000")
      end

      expect(result).to be_nil
    end
  end
end
