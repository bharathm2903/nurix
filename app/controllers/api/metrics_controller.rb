class Api::MetricsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_user!

  def index
    total_jobs = Job.count
    pending_jobs = Job.pending.count
    running_jobs = Job.running.count
    done_jobs = Job.done.count
    failed_jobs = Job.failed.count
    dlq_jobs = Job.dlq.count

    total_retries = Job.sum(:retry_count)
    jobs_with_retries = Job.where('retry_count > 0').count

    last_24h = 24.hours.ago
    jobs_last_24h = Job.where('created_at >= ?', last_24h)
    submitted_last_24h = jobs_last_24h.count
    completed_last_24h = jobs_last_24h.where(status: [Job::STATUS_DONE, Job::STATUS_DLQ]).count
    failed_last_24h = jobs_last_24h.where(status: [Job::STATUS_FAILED, Job::STATUS_DLQ]).count

    completed_jobs = Job.where.not(completed_at: nil).where.not(started_at: nil)

    user_metrics = nil
    if params[:user_id].present? || current_user
      user = params[:user_id] ? User.find_by(id: params[:user_id]) : current_user
      if user
        user_jobs = user.jobs
        user_metrics = {
          total: user_jobs.count,
          pending: user_jobs.pending.count,
          running: user_jobs.running.count,
          done: user_jobs.done.count,
          failed: user_jobs.failed.count,
          dlq: user_jobs.dlq.count,
          concurrent: user_jobs.running.count
        }
      end
    end

    render json: {
      system: {
        total_jobs: total_jobs,
        pending: pending_jobs,
        running: running_jobs,
        done: done_jobs,
        failed: failed_jobs,
        dlq: dlq_jobs,
        total_retries: total_retries,
        jobs_with_retries: jobs_with_retries
      },
      last_24h: {
        submitted: submitted_last_24h,
        completed: completed_last_24h,
        failed: failed_last_24h
      },
      user: user_metrics
    }, status: :ok
  rescue StandardError => e
    Rails.logger.error("[Metrics] Error: #{e.message}")
    render json: { error: 'Failed to fetch metrics' }, status: :internal_server_error
  end
end
