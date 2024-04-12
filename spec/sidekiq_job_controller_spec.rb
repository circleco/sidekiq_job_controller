# frozen_string_literal: true

require "spec_helper"

RSpec.describe SidekiqJobController::ServerMiddleware do
  before do
    stub_const("ConditionalTestWorker", worker_class)
    stub_const("ConditionalTestJob", job_class)
  end

  let(:worker_class) do
    Class.new do
      include Sidekiq::Worker

      def perform(param_1, param_2)
        Sidekiq.redis do |conn|
          conn.set("worker_class_output", "Performing job with #{param_1} - #{param_2}")
        end
      end
    end
  end

  let(:job_class) do
    Class.new(ActiveJob::Base) do
      queue_as :default

      def perform(param_1, param_2:)
        Sidekiq.redis do |conn|
          conn.set("job_class_output", "Performing job with #{param_1} - #{param_2}")
        end
      end
    end
  end

  # This is the sidekiq worker class we want to test with
  let(:sidekiq_worker_class) { ConditionalTestWorker }
  # This is the job controller we will use to control the sidekiq workers
  let(:sidekiq_worker_controller) { SidekiqJobController::Controller.new(class_name: sidekiq_worker_class) }
  # This is the active job class we want to test with
  let(:active_job_class) { ConditionalTestJob }
  # Active jobs run in a wrapper class inside sidekiq.
  let(:job_wrapper_class) { ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper }
  # This is the job controller we will use to control the active jobs
  let(:active_job_controller) { SidekiqJobController::Controller.new(class_name: active_job_class) }

  describe "resuming jobs" do
    context "when the job is an ActiveJob" do
      before { active_job_controller.resume_job! }

      it "performs the job", aggregate_failures: true do
        enqueue_active_job
        expect(active_job_controller.status).to eq("ConditionalTestJob jobs are running")
        expect(Sidekiq.redis { |conn| conn.get("job_class_output") }).to eq("Performing job with hello - world") # the job perform method ran
        expect(enqueued_active_jobs.size).to eq(0) # the job is not enqueued anymore
      end
    end

    context "when the job is a Sidekiq Worker" do
      before { sidekiq_worker_controller.resume_job! }

      it "performs the job", aggregate_failures: true do
        enqueue_sidekiq_worker
        expect(sidekiq_worker_controller.status).to eq("ConditionalTestWorker jobs are running")
        expect(Sidekiq.redis { |conn| conn.get("worker_class_output") }).to eq("Performing job with hello - world") # the job perform method ran
        expect(sidekiq_worker_class.jobs.size).to eq(0) # the job is not enqueued anymore
      end
    end
  end

  describe "skipping jobs" do
    context "when the job is an ActiveJob" do
      before { active_job_controller.skip_job! }

      it "skips performing the job", aggregate_failures: true do
        enqueue_active_job
        expect(active_job_controller.status).to eq("ConditionalTestJob jobs are skipped")
        expect(Sidekiq.redis { |conn| conn.get("job_class_output") }).to be_nil # the job perform method didn't run
        # the job is not enqueued for performing again (it was skipped forever)
        expect(enqueued_active_jobs.size).to eq(0)
      end
    end

    context "when the job is a Sidekiq Worker" do
      before { sidekiq_worker_controller.skip_job! }

      it "does not perform the job", aggregate_failures: true do
        enqueue_sidekiq_worker
        expect(sidekiq_worker_controller.status).to eq("ConditionalTestWorker jobs are skipped")
        expect(Sidekiq.redis { |conn| conn.get("worker_class_output") }).to be_nil # the job perform method didn't run
        # the job is not enqueued for performing again (it was skipped forever)
        expect(sidekiq_worker_class.jobs.size).to eq(0)
      end
    end
  end

  describe "requeuing jobs" do
    context "when the job is an ActiveJob" do
      before { active_job_controller.requeue_job!(5.minutes) }

      it "requeues the job", aggregate_failures: true do
        freeze_time do
          enqueue_active_job
          expect(active_job_controller.status).to eq("ConditionalTestJob jobs are requeued in 300 seconds")
          expect(Sidekiq.redis { |conn| conn.get("job_class_output") }).to be_nil # the job perform method didn't run
          expect(enqueued_active_jobs.size).to eq(1) # there is one job enqueued for performing again
          expect(enqueued_active_jobs.first["at"]).to eq(Time.now.to_i + 5.minutes) # and will be performed 5 minutes from now
        end
      end
    end

    context "when the job is a Sidekiq Worker" do
      before { sidekiq_worker_controller.requeue_job!(5.minutes) }

      it "requeues the job", aggregate_failures: true do
        freeze_time do
          enqueue_sidekiq_worker
          expect(sidekiq_worker_controller.status).to eq("ConditionalTestWorker jobs are requeued in 300 seconds")
          expect(Sidekiq.redis { |conn| conn.get("worker_class_output") }).to be_nil # the job perform method didn't run
          expect(sidekiq_worker_class.jobs.size).to eq(1) # there is one job enqueued for performing again
          # and will be performed 5 minutes from now
          expect(sidekiq_worker_class.jobs.first["at"]).to eq(Time.now.to_i + 5.minutes)
        end
      end
    end
  end

  def enqueue_sidekiq_worker
    use_sidekiq_fake do
      Sidekiq::Worker.clear_all # clear all enqueued jobs before running the test
      sidekiq_worker_class.perform_async("hello", "world") # enqueues the job
      expect(sidekiq_worker_class.jobs.size).to eq(1) # the job is enqueued
      sidekiq_worker_class.perform_one # tries to perform the job
    end
  end

  def enqueue_active_job
    use_sidekiq_fake do
      Sidekiq::Worker.clear_all # clear all enqueued jobs before running the test
      active_job_class.perform_later("hello", param_2: "world") # enqueues the job
      expect(enqueued_active_jobs.size).to eq(1) # the job is enqueued
      job_wrapper_class.perform_one # tries to perform the job
    end
  end

  def enqueued_active_jobs
    job_wrapper_class.jobs.select { |job| job["wrapped"] == active_job_class.to_s }
  end
end
