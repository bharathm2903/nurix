# ActionCable channel for broadcasting job updates to the dashboard
class JobsChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to all job updates
    stream_from "jobs:updates"
    
    # Also subscribe to user-specific updates if user_id is provided
    if params[:user_id].present?
      stream_from "jobs:user:#{params[:user_id]}"
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    # currently there is no action here it will handle all the default cleanup processes
  end
end
