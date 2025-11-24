class Job < ApplicationRecord
  belongs_to :user

  STATUS_PENDING = 'pending'
  STATUS_RUNNING = 'running'
  STATUS_DONE = 'done'
  STATUS_FAILED = 'failed'
  STATUS_DLQ = 'dlq'

  STATUSES = [STATUS_PENDING, STATUS_RUNNING, STATUS_DONE, STATUS_FAILED, STATUS_DLQ].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :payload, presence: true
  validates :retry_count, numericality: { greater_than_or_equal_to: 0 }
  validates :max_retries, numericality: { greater_than_or_equal_to: 0 }
  validates :idempotency_key, uniqueness: { allow_nil: true }

  scope :pending, -> { where(status: STATUS_PENDING) }
  scope :running, -> { where(status: STATUS_RUNNING) }
  scope :done, -> { where(status: STATUS_DONE) }
  scope :failed, -> { where(status: STATUS_FAILED) }
  scope :dlq, -> { where(status: STATUS_DLQ) }
  scope :available_for_lease, -> { pending.where('leased_at IS NULL OR leased_at < ?', 5.minutes.ago) }

  before_create :generate_trace_id, unless: :trace_id?

  after_update :broadcast_update
  after_create :broadcast_update

  def as_json
    {
      id: id,
      status: status,
      payload: payload,
      retry_count: retry_count,
      max_retries: max_retries,
      error_message: error_message,
      trace_id: trace_id,
      started_at: started_at,
      completed_at: completed_at,
      created_at: created_at
    }
  end

  def lease!(worker_id)
    return false unless can_be_leased?

    update!(
      status: STATUS_RUNNING,
      leased_at: Time.current,
      leased_by: worker_id,
      started_at: Time.current
    )
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def ack!
    update!(
      status: STATUS_DONE,
      completed_at: Time.current,
      leased_at: nil,
      leased_by: nil
    )
  end

  def fail!(error_message = nil)
    self.error_message = error_message
    self.retry_count += 1

    if retry_count > max_retries
      update!(
        status: STATUS_DLQ,
        completed_at: Time.current,
        leased_at: nil,
        leased_by: nil
      )
    else
      update!(
        status: STATUS_PENDING,
        leased_at: nil,
        leased_by: nil
      )
    end
  end

  def can_be_leased?
    return false unless status == STATUS_PENDING
    return true if leased_at.nil?
    leased_at < 5.minutes.ago
  end

  def terminal?
    [STATUS_DONE, STATUS_DLQ].include?(status)
  end

  private

  def generate_trace_id
    self.trace_id ||= SecureRandom.uuid
  end

  def broadcast_update
    # Broadcast to all subscribers
    ActionCable.server.broadcast('jobs:updates', {
      type: 'job_update',
      job_id: id,
      status: status,
      stats: {
        total: Job.count,
        pending: Job.pending.count,
        running: Job.running.count,
        done: Job.done.count,
        failed: Job.failed.count,
        dlq: Job.dlq.count
      }
    })

    # Broadcast to user-specific channel
    ActionCable.server.broadcast("jobs:user:#{user_id}", {
      type: 'job_update',
      job_id: id,
      status: status
    })
  end
end
