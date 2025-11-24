# Rake task to run the job worker
# Usage: rails job_worker:start
namespace :job_worker do
  desc "Start the job worker (polls for jobs and processes them)"
  task start: :environment do
    require_relative '../../app/workers/job_worker'
    
    worker_id = "worker-#{Process.pid}"
    Rails.logger.info("[Worker:#{worker_id}] Starting job worker...")
    
    worker = JobWorker.new(worker_id: worker_id)
    worker.start
  end
end

