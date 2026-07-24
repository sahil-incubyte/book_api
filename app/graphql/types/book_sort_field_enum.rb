# frozen_string_literal: true

module Types
  class BookSortFieldEnum < BaseEnum
    graphql_name "BookSortField"

    value "TITLE", value: :title
    value "PRICE", value: :price
    value "CREATED_AT", value: :created_at
  end
end
