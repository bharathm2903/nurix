class DashboardController < ApplicationController
  def index
    # Get overall statistics
    @stats = {
      total: Job.count,
      pending: Job.pending.count,
      running: Job.running.count,
      done: Job.done.count,
      failed: Job.failed.count,
      dlq: Job.dlq.count
    }

    # Get recent jobs (last 50)
    @recent_jobs = Job.order(created_at: :desc).limit(50)

    # Get DLQ jobs
    @dlq_jobs = Job.dlq.order(created_at: :desc).limit(20)

    # Get running jobs
    @running_jobs = Job.running.order(started_at: :desc).limit(20)
  end
end
