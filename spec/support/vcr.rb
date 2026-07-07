# frozen_string_literal: true

require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  # Automatically name cassettes after the example when tagged with `:vcr`.
  config.configure_rspec_metadata!
  # Record once, then replay from the committed cassette (works offline in CI).
  config.default_cassette_options = { record: :once }
  # Allow localhost connections (e.g. Capybara/system drivers) to pass through.
  config.ignore_localhost = true
end
