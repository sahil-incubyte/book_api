# frozen_string_literal: true

require "elasticsearch/model"

# Point every `Elasticsearch::Model`-enabled class at our cluster. Because we set
# the client on `Elasticsearch::Model` (the shared default), individual models
# don't each need their own client.
#
# In Docker the cluster is reachable at http://elasticsearch:9200; running Rails
# directly on the host it's http://localhost:9200 (see .env / .env.example).
Elasticsearch::Model.client = Elasticsearch::Client.new(
  # Default to the host-published port 9202 (see docker-compose.yml). In Docker,
  # ELASTICSEARCH_URL is set to http://elasticsearch:9200 and overrides this.
  url: ENV.fetch("ELASTICSEARCH_URL", "http://localhost:9202"),
  # Log requests in development so you can watch the Query DSL being sent.
  log: Rails.env.development?,
  # Retry transient connection blips instead of failing the whole request.
  retry_on_failure: 3,
  request_timeout: 5
)
