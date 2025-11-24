class Api::JobsController < ApplicationController

  skip_before_action :verify_authenticity_token
  before_action :authenticate_user!
  before_action :set_job, only: [:show]

  def create

    if params[:idempotency_key].present?
      existing_job = Job.find_by(idempotency_key: params[:idempotency_key], user_id: current_user.id)
      if existing_job
        render json: {
          id: existing_job.id,
          status: existing_job.status,
          trace_id: existing_job.trace_id,
          message: 'Job already exists with this idempotency key'
        }, status: :ok
        return
      end
    end

    job = Job.new(
      user: current_user,
      payload: params[:payload] || {},
      idempotency_key: params[:idempotency_key] || SecureRandom.hex(12),
      max_retries: params[:max_retries] || 3,
      status: Job::STATUS_PENDING
    )

    if job.save
      Rails.logger.info("[Job:#{job.id}] [Trace:#{job.trace_id}] Job submitted by user #{current_user.id}")
      render json: {
        id: job.id,
        status: job.status,
        trace_id: job.trace_id,
        message: 'Job submitted successfully'
      }, status: :ok
    else
      render json: {
        errors: job.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("API Error creating job: #{e.message}")
    render json: { error: 'Failed to create job' }, status: :internal_server_error
  end

  def show
    Rails.logger.info("Fetching Job - #{@job.id} Details....")
    render json: @job.as_json, status: :ok
  end

  def index
    jobs = current_user.jobs.order(created_at: :desc)
    if params[:status].present?
      jobs = jobs.where(status: params[:status])
    end

    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    offset = (page - 1) * per_page

    total_count = jobs.count
    jobs = jobs.limit(per_page).offset(offset)
    
    render json: {
      jobs: jobs.map{|job| job.as_json},
      pagination: {
        page: page,
        per_page: per_page,
        total: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }, status: :ok
  end

end
