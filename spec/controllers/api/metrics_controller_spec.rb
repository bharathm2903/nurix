require 'rails_helper'

RSpec.describe Api::MetricsController, type: :controller do
  let(:user) { create(:user) }

  before do
    request.headers['user_id'] = user.id.to_s
  end

  describe 'GET #index' do
    before do
      # Create jobs with different statuses
      create_list(:job, 2, :pending, user: user)
      create_list(:job, 3, :running, user: user)
      create_list(:job, 5, :done, user: user)
      create_list(:job, 1, :failed, user: user)
      create_list(:job, 1, :dlq, user: user)

      # Create jobs with retries
      create_list(:job, 2, :with_retries, user: user, retry_count: 2)

      # Create jobs from last 24 hours
      create(:job, :done, user: user, created_at: 12.hours.ago)
      create(:job, :failed, user: user, created_at: 6.hours.ago)

      # Create jobs older than 24 hours
      create(:job, :done, user: user, created_at: 2.days.ago)
    end

    it 'returns system metrics' do
      get :index
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('system')
      system_metrics = json_response['system']
      expect(system_metrics['total_jobs']).to eq(15)
      expect(system_metrics['pending']).to eq(2)
      expect(system_metrics['running']).to eq(3)
      expect(system_metrics['done']).to eq(5)
      expect(system_metrics['failed']).to eq(1)
      expect(system_metrics['dlq']).to eq(1)
      expect(system_metrics['total_retries']).to be >= 4
      expect(system_metrics['jobs_with_retries']).to be >= 2
    end

    it 'returns last 24h metrics' do
      get :index
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('last_24h')
      last_24h = json_response['last_24h']
      expect(last_24h['submitted']).to be >= 2
      expect(last_24h['completed']).to be >= 1
      expect(last_24h['failed']).to be >= 1
    end

    it 'returns user metrics for current user' do
      get :index
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('user')
      user_metrics = json_response['user']
      expect(user_metrics['total']).to eq(15)
      expect(user_metrics['pending']).to eq(2)
      expect(user_metrics['running']).to eq(3)
      expect(user_metrics['done']).to eq(5)
      expect(user_metrics['failed']).to eq(1)
      expect(user_metrics['dlq']).to eq(1)
      expect(user_metrics['concurrent']).to eq(3)
    end

    it 'returns user metrics for specified user_id' do
      other_user = create(:user)
      create_list(:job, 3, :pending, user: other_user)
      
      get :index, params: { user_id: other_user.id }
      json_response = JSON.parse(response.body)
      
      user_metrics = json_response['user']
      expect(user_metrics['total']).to eq(3)
      expect(user_metrics['pending']).to eq(3)
    end

    it 'returns nil user metrics when user_id not found' do
      get :index, params: { user_id: 99999 }
      json_response = JSON.parse(response.body)
      
      expect(json_response['user']).to be_nil
    end

    context 'when user is not authenticated' do
      before do
        request.headers['user_id'] = nil
      end

      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User Not Found')
      end
    end

    context 'when an error occurs' do
      before do
        allow(Job).to receive(:count).and_raise(StandardError.new('Database error'))
      end

      it 'returns internal server error' do
        get :index
        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Failed to fetch metrics')
      end
    end
  end
end

