# frozen_string_literal: true

module SidekiqJobController
  class ServerMiddleware
    def call(job, payload, _queue)
      class_name = payload["wrapped"] || payload["class"]

      controller_result = SidekiqJobController::Controller.new(
        class_name: class_name, job: job, payload: payload
      ).fetch_execution_action

      if controller_result.blank?
        yield
      elsif controller_result["action"] == "skip"
        log("FORCED SKIP ACTIVATED: Skipped performing job #{class_name} - #{job.jid}")
      elsif controller_result["action"] == "requeue"
        log("FORCED REQUEUE ACTIVATED: Requeuing job in #{controller_result["in"].to_i} seconds - #{class_name} - #{job.jid}")
        Sidekiq::Client.push(payload.merge("at" => Time.now.to_i + controller_result["in"].to_i))
      else
        log("UNEXPECTED ACTION: #{controller_result["action"]} is not recognized in #{class_name} - #{job.jid}")
        yield
      end
    end

    private

    def log(message)
      if defined?(Rails)
        Rails.logger.info message
      else
        puts message
      end
    end
  end
end
