# frozen_string_literal: true

# Convenience helper for executing GraphQL documents directly against the schema
# in unit specs, returning the result as a plain hash.
module GraphqlHelper
  def execute_graphql(query, variables: {}, context: {})
    BookApiSchema.execute(query, variables: variables, context: context).to_h
  end
end

RSpec.configure do |config|
  config.include GraphqlHelper
end
