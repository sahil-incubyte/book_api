# frozen_string_literal: true

module Types
  class SortDirectionEnum < BaseEnum
    graphql_name "SortDirection"

    value "ASC", value: :asc
    value "DESC", value: :desc
  end
end
