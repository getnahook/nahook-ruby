# frozen_string_literal: true

require_relative "lib/nahook/version"

Gem::Specification.new do |s|
  s.name        = "nahook"
  s.version     = Nahook::VERSION
  s.summary     = "Official Ruby SDK for the Nahook webhook platform"
  s.description = "Ruby client for sending webhooks and managing resources through the Nahook API. " \
                  "Supports direct endpoint delivery, fan-out by event type, batch operations, " \
                  "and full management API access."
  s.authors     = ["Nahook"]
  s.email       = ["support@nahook.com"]
  s.license     = "MIT"
  s.homepage    = "https://github.com/jmatom/nahook-ruby"

  s.metadata = {
    "homepage_uri"      => s.homepage,
    "source_code_uri"   => s.homepage,
    "changelog_uri"     => "#{s.homepage}/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://docs.nahook.com/sdks/ruby",
    "rubygems_mfa_required" => "true"
  }

  s.required_ruby_version = ">= 3.0"
  s.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]

  s.add_dependency "faraday", "~> 2.0"
end
