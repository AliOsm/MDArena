ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "fileutils"

# Parallel tests can race while generating Vite manifests. Build once up front so
# workers only ever read from a stable manifest.
manifest_path = Rails.root.join("public", "vite-test", ".vite", "manifest.json")
if !manifest_path.exist? || manifest_path.read.strip == "{}"
  lock_path = Rails.root.join("tmp", "vite-test-build.lock")
  FileUtils.mkdir_p(lock_path.dirname)

  File.open(lock_path, File::CREAT | File::RDWR) do |f|
    f.flock(File::LOCK_EX)

    if !manifest_path.exist? || manifest_path.read.strip == "{}"
      success = system({ "RAILS_ENV" => "test" }, "bin/vite", "build")
      raise "Vite build failed" unless success
    end
  end
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    parallelize_setup do |worker|
      # Isolate bare git repos per worker so tests don't fight over file locks.
      repos_root = Rails.root.join("tmp", "repos-test-#{worker}").to_s
      Rails.configuration.repos_root = repos_root
      FileUtils.mkdir_p(repos_root)
    end

    fixtures :all
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
