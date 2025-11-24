# Seed data for development/testing
# Run with: bin/rails db:seed

# Create a test user if it doesn't exist
user = User.find_or_create_by!(id: 1) do |u|
  u.name = "Test User"
  u.age = 30
end

puts "Created/Found user: #{user.id} - #{user.name}"

# Optionally create some sample jobs for testing
if Rails.env.development? && Job.count == 0
  puts "Creating sample jobs..."
  
  # Create a few sample jobs with different statuses
  Job.create!(
    user: user,
    payload: { type: 'sleep', duration: 1 },
    status: Job::STATUS_PENDING,
    max_retries: 3
  )
  
  Job.create!(
    user: user,
    payload: { type: 'compute', iterations: 1000 },
    status: Job::STATUS_DONE,
    max_retries: 3,
    started_at: 1.hour.ago,
    completed_at: 1.hour.ago + 2.seconds
  )
  
  puts "Created sample jobs"
end

puts "Seed data loaded successfully!"
