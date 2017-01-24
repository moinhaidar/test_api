class Api::V1::SessionsController < Api::V1::BaseController

  skip_before_action :authenticate_user!

  # URL : /api/v1/sessions
  # METHOD : POST
  # Required Parameters
    # => email, password
  # Example
    # => params =  { email: 'foo@coi.com', password: 'changeme' }
    # => HTTParty.post('#{BASE_URL}/api/v1/sessions', body: params)

  def create
    user = User.find_first_by_auth_conditions(email: params[:email])
    return api_error(status: 401, errors: ['Email has not been registered with us yet']) unless user
    return api_error(status: 401, errors: ['Email has not been activated yet']) unless user.activated?
    return api_error(status: 401, errors: ['Email has not been approved from Admin']) unless user.approved?

    if user && user.valid_password?(params[:password])
      self.current_user = user
      token = Tiddle.create_and_return_token(user, request)
      user_hash = JSON.parse(Api::V1::SessionSerializer.new(user, root: false).to_json)
      user_hash['token'] = token
      render(
        json: { token: JsonWebToken.encode(user_hash) },
        status: 201
      )
    else
      return api_error(status: 401, errors: ['Invalid Password'])
    end
  end
  
end