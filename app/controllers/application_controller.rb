class ApplicationController < ActionController::Base

    def authenticate_user!
        # since concentrating more on job level things just handled user in a basic manner
        user_id = request.headers['user_id'] || params[:user_id] || 1 #"QmhhcmF0aDox"
        # begin
        #     dec_user_id = Base64.decode64(user_id).split(":").last
        # rescue ArgumentError
        #     render json: { error: "Please Enter Valid Encoded User-Id" }, status: :bad_request and return
        # end

        # if dec_user_id.blank?
        #     render json: { error: "Please Enter Valid Encoded User-Id" }, status: :bad_request and return
        # end

        # @current_user = User.find_by(id: dec_user_id)
        @current_user = User.find_by(id: user_id)

        unless @current_user
            render json: { error: 'User Not Found' }, status: :unauthorized and return
        end
    end

    def current_user
        @current_user
    end

      def set_job
        @job = current_user.jobs.find(params[:id])
    rescue ActiveRecord::RecordNotFound
        render json: { error: 'Job Not Found' }, status: :not_found
    end
end
