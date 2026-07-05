class AddNotNullConstraintsToBooks < ActiveRecord::Migration[7.2]
  # The Book model validates presence of title/author/price, but the database
  # had no matching NOT NULL constraints — leaving room for bad data written
  # outside the model. This migration aligns the schema with the model.
  #
  # strong_migrations flags change_column_null on an existing column because on
  # large tables it takes a full-table lock while every row is checked. Here the
  # table is effectively empty (a fresh learning app), so the rewrite is
  # instantaneous and safe. We document that with `safety_assured`. See
  # docs/MIGRATIONS.md for the zero-downtime pattern to use on a large table.
  def change
    safety_assured do
      change_column_null :books, :title, false
      change_column_null :books, :author, false
      change_column_null :books, :price, false
    end
  end
end
