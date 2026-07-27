# frozen_string_literal: true

# Helpers for specs that exercise the real Elasticsearch integration. Tag an
# example group with `:elasticsearch` to opt in: each such example gets a fresh
# index, and the group is skipped automatically when no cluster is reachable so
# the rest of the suite still runs on a machine without ES.
#
# Auto-indexing callbacks are OFF in the test env (see Searchable), so these
# specs index explicitly via `index_books!` after creating their records.
module ElasticsearchHelpers
  def self.reachable?
    Book.__elasticsearch__.client.ping
  rescue StandardError
    false
  end

  # Drop and recreate the Book index so each example starts empty and clean.
  def recreate_book_index!
    Book.__elasticsearch__.create_index!(force: true)
  end

  # Index the given books and refresh so they're immediately searchable
  # (ES otherwise makes new docs visible only ~once per second).
  def index_books!(*books)
    books.flatten.each { |book| book.__elasticsearch__.index_document }
    Book.__elasticsearch__.refresh_index!
  end
end

RSpec.configure do |config|
  config.include ElasticsearchHelpers, :elasticsearch

  config.before(:each, :elasticsearch) do
    unless ElasticsearchHelpers.reachable?
      skip "Elasticsearch not reachable at #{ENV.fetch('ELASTICSEARCH_URL', 'http://localhost:9202')}"
    end
    recreate_book_index!
  end
end
