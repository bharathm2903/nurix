require 'rails_helper'

RSpec.describe Api::JobsController, type: :controller do
  let(:user) { create(:user) }

  before do
    request.headers['user_id'] = user.id.to_s
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          payload: { action: 'test_action', data: 'test_data' },
          max_retries: 5
        }
      end

      it 'creates a new job' do
        expect {
          post :create, params: valid_params
        }.to change(Job, :count).by(1)
      end

      it 'returns success response' do
        post :create, params: valid_params
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Job submitted successfully')
        expect(json_response['status']).to eq(Job::STATUS_PENDING)
        expect(json_response).to have_key('id')
        expect(json_response).to have_key('trace_id')
      end

      it 'associates job with current user' do
        post :create, params: valid_params
        job = Job.last
        expect(job.user).to eq(user)
      end

      it 'sets default max_retries if not provided' do
        post :create, params: { payload: { action: 'test' } }
        job = Job.last
        expect(job.max_retries).to eq(3)
      end
    end

    context 'with idempotency_key' do
      let(:idempotency_key) { SecureRandom.hex(12) }
      let(:params) do
        {
          payload: { action: 'test' },
          idempotency_key: idempotency_key
        }
      end

      it 'returns existing job if idempotency_key matches' do
        existing_job = create(:job, user: user, idempotency_key: idempotency_key)
        
        expect {
          post :create, params: params
        }.not_to change(Job, :count)

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(existing_job.id)
        expect(json_response['message']).to eq('Job already exists with this idempotency key')
      end

      it 'creates new job if idempotency_key is different' do
        create(:job, user: user, idempotency_key: 'different_key')
        
        expect {
          post :create, params: params
        }.to change(Job, :count).by(1)
      end
    end

    context 'with invalid parameters' do
      it 'returns error when payload is missing' do
        post :create, params: { max_retries: 5 }
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
      end
    end

    context 'when user is not authenticated' do
      before do
        request.headers['user_id'] = nil
      end

      it 'returns unauthorized' do
        post :create, params: { payload: { action: 'test' } }
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User Not Found')
      end
    end
  end

  describe 'GET #show' do
    let(:job) { create(:job, user: user) }

    it 'returns job details' do
      get :show, params: { id: job.id }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['id']).to eq(job.id)
      expect(json_response['status']).to eq(job.status)
      expect(json_response['trace_id']).to eq(job.trace_id)
    end

    it 'returns not found for non-existent job' do
      get :show, params: { id: 99999 }
      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Job Not Found')
    end

    it 'returns not found for job belonging to different user' do
      other_user = create(:user)
      other_job = create(:job, user: other_user)
      get :show, params: { id: other_job.id }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #index' do
    before do
      create_list(:job, 3, :pending, user: user)
      create_list(:job, 2, :done, user: user)
      create_list(:job, 1, :failed, user: user)
    end

    it 'returns all jobs for current user' do
      get :index
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['jobs'].count).to eq(6)
      expect(json_response).to have_key('pagination')
    end

    it 'filters by status' do
      get :index, params: { status: Job::STATUS_PENDING }
      json_response = JSON.parse(response.body)
      expect(json_response['jobs'].count).to eq(3)
      json_response['jobs'].each do |job|
        expect(job['status']).to eq(Job::STATUS_PENDING)
      end
    end

    it 'paginates results' do
      get :index, params: { page: 1, per_page: 2 }
      json_response = JSON.parse(response.body)
      expect(json_response['jobs'].count).to eq(2)
      expect(json_response['pagination']['page']).to eq(1)
      expect(json_response['pagination']['per_page']).to eq(2)
      expect(json_response['pagination']['total']).to eq(6)
    end

    it 'returns jobs in descending order by created_at' do
      get :index
      json_response = JSON.parse(response.body)
      jobs = json_response['jobs']
      expect(jobs.first['id']).to be > jobs.last['id']
    end
  end
end

