require 'rails_helper'

RSpec.describe Job, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    let(:user) { create(:user) }

    it { should validate_inclusion_of(:status).in_array(Job::STATUSES) }
    it { should validate_presence_of(:payload) }
    it { should validate_numericality_of(:retry_count).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:max_retries).is_greater_than_or_equal_to(0) }
    it { should validate_uniqueness_of(:idempotency_key).allow_nil }

    context 'with valid attributes' do
      it 'is valid' do
        job = build(:job, user: user)
        expect(job).to be_valid
      end
    end

    context 'with invalid status' do
      it 'is invalid' do
        job = build(:job, user: user, status: 'invalid_status')
        expect(job).not_to be_valid
        expect(job.errors[:status]).to include('is not included in the list')
      end
    end

    context 'without payload' do
      it 'is invalid' do
        job = build(:job, user: user, payload: nil)
        expect(job).not_to be_valid
        expect(job.errors[:payload]).to include("can't be blank")
      end
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }

    before do
      create(:job, :pending, user: user)
      create(:job, :running, user: user)
      create(:job, :done, user: user)
      create(:job, :failed, user: user)
      create(:job, :dlq, user: user)
    end

    it 'filters pending jobs' do
      expect(Job.pending.count).to eq(1)
      expect(Job.pending.first.status).to eq(Job::STATUS_PENDING)
    end

    it 'filters running jobs' do
      expect(Job.running.count).to eq(1)
      expect(Job.running.first.status).to eq(Job::STATUS_RUNNING)
    end

    it 'filters done jobs' do
      expect(Job.done.count).to eq(1)
      expect(Job.done.first.status).to eq(Job::STATUS_DONE)
    end

    it 'filters failed jobs' do
      expect(Job.failed.count).to eq(1)
      expect(Job.failed.first.status).to eq(Job::STATUS_FAILED)
    end

    it 'filters dlq jobs' do
      expect(Job.dlq.count).to eq(1)
      expect(Job.dlq.first.status).to eq(Job::STATUS_DLQ)
    end

    it 'filters available for lease jobs' do
      job = create(:job, :pending, user: user, leased_at: 10.minutes.ago)
      expect(Job.available_for_lease).to include(job)
    end
  end

  describe 'callbacks' do
    let(:user) { create(:user) }

    it 'generates trace_id before create if not present' do
      job = create(:job, user: user, trace_id: nil)
      expect(job.trace_id).to be_present
      expect(job.trace_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
    end

    it 'does not override existing trace_id' do
      existing_trace_id = SecureRandom.uuid
      job = create(:job, user: user, trace_id: existing_trace_id)
      expect(job.trace_id).to eq(existing_trace_id)
    end
  end

  describe '#lease!' do
    let(:user) { create(:user) }
    let(:job) { create(:job, :pending, user: user) }

    context 'when job can be leased' do
      it 'updates job to running status' do
        expect(job.lease!('worker-1')).to be true
        job.reload
        expect(job.status).to eq(Job::STATUS_RUNNING)
        expect(job.leased_at).to be_present
        expect(job.leased_by).to eq('worker-1')
        expect(job.started_at).to be_present
      end
    end

    context 'when job cannot be leased' do
      it 'returns false for running job' do
        running_job = create(:job, :running, user: user)
        expect(running_job.lease!('worker-2')).to be false
      end

      it 'returns false for recently leased job' do
        job.update(leased_at: 1.minute.ago)
        expect(job.lease!('worker-2')).to be false
      end
    end
  end

  describe '#ack!' do
    let(:user) { create(:user) }
    let(:job) { create(:job, :running, user: user) }

    it 'marks job as done' do
      job.ack!
      job.reload
      expect(job.status).to eq(Job::STATUS_DONE)
      expect(job.completed_at).to be_present
      expect(job.leased_at).to be_nil
      expect(job.leased_by).to be_nil
    end
  end

  describe '#fail!' do
    let(:user) { create(:user) }
    let(:job) { create(:job, :running, user: user, retry_count: 0, max_retries: 3) }

    context 'when retry count is below max retries' do
      it 'resets job to pending and increments retry count' do
        job.fail!('Test error')
        job.reload
        expect(job.status).to eq(Job::STATUS_PENDING)
        expect(job.retry_count).to eq(1)
        expect(job.error_message).to eq('Test error')
        expect(job.leased_at).to be_nil
        expect(job.leased_by).to be_nil
      end
    end

    context 'when retry count exceeds max retries' do
      it 'moves job to DLQ' do
        job.update(retry_count: 3)
        job.fail!('Max retries exceeded')
        job.reload
        expect(job.status).to eq(Job::STATUS_DLQ)
        expect(job.retry_count).to eq(4)
        expect(job.error_message).to eq('Max retries exceeded')
        expect(job.completed_at).to be_present
        expect(job.leased_at).to be_nil
        expect(job.leased_by).to be_nil
      end
    end
  end

  describe '#can_be_leased?' do
    let(:user) { create(:user) }

    it 'returns true for pending job without lease' do
      job = create(:job, :pending, user: user, leased_at: nil)
      expect(job.can_be_leased?).to be true
    end

    it 'returns true for pending job with expired lease' do
      job = create(:job, :pending, user: user, leased_at: 10.minutes.ago)
      expect(job.can_be_leased?).to be true
    end

    it 'returns false for running job' do
      job = create(:job, :running, user: user)
      expect(job.can_be_leased?).to be false
    end

    it 'returns false for recently leased job' do
      job = create(:job, :pending, user: user, leased_at: 1.minute.ago)
      expect(job.can_be_leased?).to be false
    end
  end

  describe '#terminal?' do
    let(:user) { create(:user) }

    it 'returns true for done job' do
      job = create(:job, :done, user: user)
      expect(job.terminal?).to be true
    end

    it 'returns true for dlq job' do
      job = create(:job, :dlq, user: user)
      expect(job.terminal?).to be true
    end

    it 'returns false for pending job' do
      job = create(:job, :pending, user: user)
      expect(job.terminal?).to be false
    end

    it 'returns false for running job' do
      job = create(:job, :running, user: user)
      expect(job.terminal?).to be false
    end
  end

  describe '#as_json' do
    let(:user) { create(:user) }
    let(:job) { create(:job, :done, user: user, started_at: 1.hour.ago, completed_at: Time.current) }

    it 'returns correct JSON representation' do
      json = job.as_json
      expect(json).to include(
        id: job.id,
        status: job.status,
        payload: job.payload,
        retry_count: job.retry_count,
        max_retries: job.max_retries,
        error_message: job.error_message,
        trace_id: job.trace_id
      )
      expect(json).to have_key(:started_at)
      expect(json).to have_key(:completed_at)
      expect(json).to have_key(:created_at)
    end
  end
end

