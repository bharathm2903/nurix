class JobProcessorJob < ApplicationJob
  queue_as :default
  def perform(job_id, worker_id = nil)
    worker_id ||= "worker-#{Process.pid}-#{Thread.current.object_id}"
    
    job = Job.find_by(id: job_id)
    return unless job
    unless job.status == Job::STATUS_RUNNING
      Rails.logger.warn("[Worker:#{worker_id}] [Job:#{job.id}] [Trace:#{job.trace_id}] Job not in running state (status: #{job.status}), skipping")
      return
    end

    Rails.logger.info("[Worker:#{worker_id}] [Job:#{job.id}] [Trace:#{job.trace_id}] Processing job")

    begin
      result = process_job_payload(job.payload, job)
      job.ack!
      Rails.logger.info("[Worker:#{worker_id}] [Job:#{job.id}] [Trace:#{job.trace_id}] Job completed successfully")
      result
    rescue StandardError => e
      error_message = "#{e.class}: #{e.message}"
      Rails.logger.error("[Worker:#{worker_id}] [Job:#{job.id}] [Trace:#{job.trace_id}] Job failed: #{error_message}")
      Rails.logger.error("[Worker:#{worker_id}] [Job:#{job.id}] [Trace:#{job.trace_id}] Backtrace: #{e.backtrace.first(5).join("\n")}")
      job.fail!(error_message)
      if job.status == Job::STATUS_PENDING
        Rails.logger.info("[Worker:#{worker_id}] [Job:#{job.id}] [Trace:#{job.trace_id}] Job re-queued for retry (attempt #{job.retry_count}/#{job.max_retries})")
      else
        Rails.logger.warn("[Worker:#{worker_id}] [Job:#{job.id}] [Trace:#{job.trace_id}] Job moved to DLQ after #{job.retry_count} retries")
      end
      raise "Job Execution Failed"
    end
  end

  private

  def process_job_payload(payload, job)
    job_type = payload['type'] || 'default'
    case job_type
    when 'sleep'
      sleep_duration = payload['duration'] || 1
      sleep(sleep_duration)
      { status: 'completed', duration: sleep_duration }
      
    when 'compute'
      iterations = payload['iterations'] || 1000
      result = 0
      iterations.times { result += Math.sqrt(rand) }
      { status: 'completed', result: result.round(2) }
      
    when 'fail'
      raise StandardError, payload['error_message'] || 'Simulated failure'
      
    else
      { status: 'completed', message: 'Job processed successfully' }
    end
  end
end

