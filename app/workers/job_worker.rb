class JobWorker
  attr_reader :worker_id, :running, :poll_interval

  def initialize(worker_id: nil, poll_interval: 2)
    @worker_id = worker_id || "worker-#{Process.pid}-#{Time.now.to_i}"
    @poll_interval = poll_interval
    @running = false
  end

  def start
    @running = true
    puts "[Worker:#{@worker_id}] Worker started, polling every #{@poll_interval}s"
    Rails.logger.info("[Worker:#{@worker_id}] Worker started, polling every #{@poll_interval}s")

    @should_stop = false
    Signal.trap('INT') { @should_stop = true }
    Signal.trap('TERM') { @should_stop = true }

    loop do
      # Check for stop signal
      if @should_stop
        puts "[Worker:#{@worker_id}] Received stop signal, shutting down..."
        @running = false
        break
      end

      break unless @running

      begin
        process_available_jobs
      rescue StandardError => e
        puts "[Worker:#{@worker_id}] Error in worker loop: #{e.message}"
        Rails.logger.error("[Worker:#{@worker_id}] Error in worker loop: #{e.message}")
        Rails.logger.error("[Worker:#{@worker_id}] Backtrace: #{e.backtrace.first(5).join("\n")}")
      end

      sleep(@poll_interval) if @running
    end

    puts "[Worker:#{@worker_id}] Worker stopped"
    Rails.logger.info("[Worker:#{@worker_id}] Worker stopped")
  end

  def stop
    @should_stop = true
    @running = false
  end

  private

  def process_available_jobs

    available_jobs = Job.available_for_lease.limit(10)

    if available_jobs.any?
      puts "[Worker:#{@worker_id}] Found #{available_jobs.count} available job(s)"
    end

    available_jobs.each do |job|
      # Check if user has exceeded concurrent job limit (max 5 concurrent jobs per user)
      user_concurrent = job.user.jobs.running.count
      if user_concurrent >= 5
        puts "[Worker:#{@worker_id}] [Job:#{job.id}] User #{job.user.id} has #{user_concurrent} concurrent jobs, skipping"
        Rails.logger.debug("[Worker:#{@worker_id}] [Job:#{job.id}] User #{job.user.id} has #{user_concurrent} concurrent jobs, skipping")
        next
      end

      if job.lease!(@worker_id)
        puts "[Worker:#{@worker_id}] [Job:#{job.id}] Leased job for processing"
        Rails.logger.info("[Worker:#{@worker_id}] [Job:#{job.id}] [Trace:#{job.trace_id}] Leased job for processing")

        JobProcessorJob.perform_later(job.id, @worker_id)
      else
        Rails.logger.debug("[Worker:#{@worker_id}] [Job:#{job.id}] Could not lease job (may be leased by another worker)")
      end
    end
  end
end