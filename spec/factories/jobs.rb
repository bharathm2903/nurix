FactoryBot.define do
  factory :job do
    association :user
    payload { { "action" => "test_action", "data" => "test_data" } }
    status { Job::STATUS_PENDING }
    retry_count { 0 }
    max_retries { 3 }
    idempotency_key { SecureRandom.hex(12) }
    trace_id { SecureRandom.uuid }

    trait :pending do
      status { Job::STATUS_PENDING }
    end

    trait :running do
      status { Job::STATUS_RUNNING }
      leased_at { Time.current }
      leased_by { "worker-1" }
      started_at { Time.current }
    end

    trait :done do
      status { Job::STATUS_DONE }
      started_at { 1.hour.ago }
      completed_at { Time.current }
    end

    trait :failed do
      status { Job::STATUS_FAILED }
      error_message { "Test error message" }
      retry_count { 1 }
    end

    trait :dlq do
      status { Job::STATUS_DLQ }
      error_message { "Max retries exceeded" }
      retry_count { 4 }
      max_retries { 3 }
      completed_at { Time.current }
    end

    trait :with_retries do
      retry_count { 2 }
    end
  end
end

