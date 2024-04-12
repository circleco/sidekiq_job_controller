# frozen_string_literal: true

require "sidekiq_job_controller"
require "sidekiq/testing"
require "fakeredis/rspec"
require "active_support/testing/time_helpers"


RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end


  config.before(:suite) do
    Sidekiq::Testing.server_middleware do |chain|
      chain.add SidekiqJobController::ServerMiddleware
    end
  end

  config.before(:each) do
    Sidekiq::Worker.clear_all
    Sidekiq.redis(&:flushdb)
  end
end

def use_sidekiq_fake
  old_job_adapter = ActiveJob::Base.queue_adapter
  ActiveJob::Base.queue_adapter = :sidekiq
  Sidekiq::Testing.fake! do
    yield
  ensure
    ActiveJob::Base.queue_adapter = old_job_adapter
  end
end
