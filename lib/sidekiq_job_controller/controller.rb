module SidekiqJobController
  class Controller
    attr_reader :class_name, :job, :payload

    def initialize(class_name:, job: nil, payload: nil)
      @class_name = class_name
      @job = job
      @payload = payload
    end

    def resume_job!
      Sidekiq.redis do |conn|
        conn.del(job_controller_key)
      end
      status
    end

    def skip_job!
      Sidekiq.redis do |conn|
        conn.mapped_hmset(job_controller_key, { action: :skip })
      end
      status
    end

    def requeue_job!(seconds)
      Sidekiq.redis do |conn|
        conn.mapped_hmset(job_controller_key, { action: :requeue, in: seconds.to_i })
      end
      status
    end

    def status
      "#{class_name} jobs are #{current_state}"
    end

    def fetch_execution_action
      Sidekiq.redis do |conn|
        conn.hgetall(job_controller_key)
      end
    end

    private
    def job_controller_key
      "sidekiq:job_controller:#{class_name}"
    end

    def current_state
      controller_result = fetch_execution_action

      return "running" unless controller_result.present?
      return "skipped" if controller_result["action"] == "skip"
      return "requeued in #{controller_result["in"].to_i} seconds" if controller_result["action"] == "requeue"

      "in unknown state: #{controller_result["action"]}"
    end
  end
end
