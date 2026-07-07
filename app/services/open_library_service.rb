# frozen_string_literal: true

require "faraday"
require "json"

# Fetches book metadata from the Open Library public API.
#
#   OpenLibraryService.new.fetch_book("0451526538")
#   # => { title: "...", authors: ["..."], publish_date: "..." } or nil
#
# The Faraday connection is injectable so specs can drive it deterministically.
class OpenLibraryService
  BASE_URL = "https://openlibrary.org"

  def initialize(connection: nil)
    @connection = connection || Faraday.new(url: BASE_URL)
  end

  # Returns a hash of book details for the given ISBN, or nil when not found.
  def fetch_book(isbn)
    bibkey = "ISBN:#{isbn}"
    response = @connection.get("/api/books", bibkeys: bibkey, format: "json", jscmd: "data")

    return nil unless response.success?

    data = JSON.parse(response.body)
    book = data[bibkey]
    return nil if book.nil?

    {
      title: book["title"],
      authors: Array(book["authors"]).map { |a| a["name"] },
      publish_date: book["publish_date"]
    }
  end
end
