module Api
  module V1
    class BaseController < ActionController::Base

      # Prevent CSRF attacks by raising an exception.
      # For APIs, you may want to use :null_session instead.
      protect_from_forgery with: :null_session

      rescue_from ActiveRecord::RecordNotFound, with: :not_found!

      before_action :destroy_session, :authenticate_user!
      
      attr_accessor :current_user
      
      respond_to :json

      protected

        def destroy_session
          # :skip will not a set a cookie in the response nor update the session state
          request.session_options[:skip] = true
        end

        def unauthenticated!(msg)
          response.headers['WWW-Authenticate'] = "Token realm=Application"
          render json: { messages: msg }, status: 401
        end

        def unauthorized!
          render json: { messages: 'Not Authorized' }, status: 403
        end

        def invalid_resource!(errors = [])
          api_error(status: 422, errors: errors)
        end

        def not_found!
          return api_error(status: 404, errors: 'The page you requested is not found')
        end

        def api_error(status: 500, errors: [])
          unless Rails.env.production?
            puts errors.full_messages if errors.respond_to? :full_messages
          end
          return api_error(status: 500, errors: 'Something went wrong, please try again') if errors.empty?
          render json: jsonapi_format(errors).to_json, status: status
        end

        def single_token_authenticate_user!
          token, options = ActionController::HttpAuthentication::Token.token_and_options(request)
          user_email = options.blank? ? nil : options[:email]
          user = user_email && User.find_by(email: user_email)
          
          unless user && user.activated?
            user.reset_authentication_token
            return unauthenticated!('Your profile has not been activated yet, please check your email and click on activation link.')
          end

          unless user && user.approved?
            user.reset_authentication_token
            return unauthenticated!('Your profile has not been approved, please try later.')
          end

          # Note - we use secure_compare to compare the received token with the user's saved token because otherwise our app would be vulnerable to timing attacks.
          # https://codahale.com/a-lesson-in-timing-attacks/
          # Devise.secure_compare(user.authentication_token, token)
          if user && ActiveSupport::SecurityUtils.secure_compare(user.authentication_token, token)
            @current_user = user
          else
            return unauthenticated!('Your session has expired, please login.')
          end
        end

        def authenticate_user!
          user_email = request.headers['X-USER-EMAIL']
          user = user_email && User.find_by(email: user_email)
          return unauthenticated!('Unauthorized User') unless user

          unless user.activated?
            Tiddle.purge_old_tokens(user)
            return unauthenticated!('Your profile has not been activated yet, please check your email and click on activation link.')
          end

          unless user.approved?
            Tiddle.purge_old_tokens(user)
            return unauthenticated!('Your profile has not been approved, please try later.')
          end
          
          if Tiddle.find_token(user, request.headers['X-USER-TOKEN'])
            @current_user = user
          else
            return unauthenticated!('Your session has expired, please login.')
          end
        end

        def paginate(resource)
          resource = resource.page(params[:page] || 1)
          if params[:per_page]
            resource = resource.per(params[:per_page])
          end
          resource
        end

        def meta_attributes(object)
          {
            current_page: object.current_page,
            next_page: object.next_page,
            total_pages: object.total_pages,
            total_records: object.total_count
          }
        end

      private

        def jsonapi_format(errors)
          return { messages: errors } if errors.is_a? String
          return { messages: errors } if errors.is_a? Array
          return { messages: errors.full_messages} if errors.respond_to? :full_messages
          errors_hash = {}
          errors.messages.each do |attribute, error|
            array_hash = []
            error.each do |e|
              array_hash << {attribute: attribute, message: e}
            end
            errors_hash.merge!({ attribute => array_hash })
          end
          return errors_hash
        end

    end
  end
end

# Success:
#   200 :ok
#   201 :created
#   202 :accepted
#   204 :no_content
  
# Client Error:
#   400 :bad_request
#   401 :unauthorized
#   403 :forbidden
#   404 :not_found
#   406 :not_acceptable
#   422 :unprocessable_entity

# Server Error  
#   500 :internal_server_error
#   501 :not_implemented
#   503 :service_unavailable