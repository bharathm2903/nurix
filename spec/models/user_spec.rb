require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:jobs).dependent(:destroy) }
  end

  describe 'job association' do
    let(:user) { create(:user) }

    it 'destroys associated jobs when user is destroyed' do
      job1 = create(:job, user: user)
      job2 = create(:job, user: user)
      
      expect {
        user.destroy
      }.to change(Job, :count).by(-2)
      
      expect(Job.find_by(id: job1.id)).to be_nil
      expect(Job.find_by(id: job2.id)).to be_nil
    end
  end
end

