# frozen_string_literal: true

namespace :es do
  desc "Recreate the Book Elasticsearch index and import every book"
  task reindex: :environment do
    puts "Recreating index #{Book.index_name}..."
    # force: true drops an existing index first, then applies our mapping.
    Book.__elasticsearch__.create_index!(force: true)

    puts "Importing #{Book.count} books..."
    # refresh: true makes the imported docs immediately searchable (handy for a
    # manual reindex; ES otherwise refreshes ~once per second).
    errors = Book.import(refresh: true)

    if errors.zero?
      puts "Done — index is in sync."
    else
      warn "Completed with #{errors} failed document(s); check the logs."
    end
  end
end
