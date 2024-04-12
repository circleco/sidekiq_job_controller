# frozen_string_literal: true

require "sidekiq"
require "active_job"

module SidekiqJobController
end

require "sidekiq_job_controller/controller"
require "sidekiq_job_controller/server_middleware"

