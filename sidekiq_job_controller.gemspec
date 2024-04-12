# frozen_string_literal: true

require_relative "lib/sidekiq_job_controller/version"

Gem::Specification.new do |spec|
  spec.name = "sidekiq_job_controller"
  spec.version = SidekiqJobController::VERSION
  spec.authors = ["Benjamín Silva"]

  spec.summary = "Sidekiq middleware to manually skip or delay Sidekiq jobs."
  spec.description = "Sidekiq middleware that allows for immediate control over job processing in Sidekiq, providing tools to skip, delay, or modify job executions directly from the console, ideal for handling job failures or system stress without needing deployment."
  spec.homepage = "https://github.com/circleco/sidekiq_job_controller"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/circleco/sidekiq_job_controller"
  spec.metadata["changelog_uri"] = "https://github.com/circleco/sidekiq_job_controller/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Gem dependencies
  spec.add_runtime_dependency "sidekiq", ">= 6.0"
  spec.add_runtime_dependency "activejob", ">= 6.0"

  # Development dependencies
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "standard", ">= 1.3"
  spec.add_development_dependency "activesupport", ">= 7.1"
  spec.add_development_dependency "fakeredis", ">= 0.8"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
