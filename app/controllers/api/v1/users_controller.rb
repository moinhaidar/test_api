class Api::V1::UsersController < Api::V1::BaseController
    
  skip_before_action :authenticate_user!, only: [:create, :activate_account, :geo_location]
  before_action :find_user, only: [:signout, :destroy, :approve, :unapprove]

  # URL : /api/v1/users
  # METHOD : GET
  # Optional URL Parameters
    # => page, per_page
  # Example
    # => #{BASE_URL}/api/v1/users?page=2&per_page=3
  def index
    users = paginate(current_user.customers(params))
    render(
      json: ActiveModel::ArraySerializer.new(
        users,
        each_serializer: Api::V1::UserSerializer,
        root: 'users',
        meta: meta_attributes(users)
      )
    )
  end

  # URL : /api/v1/users/create
  # METHOD : POST
  # Required Parameters
    # => name, email, password, password_confirmation, customer_type
  # Example
    # => params
      # {
      #   "user": {
      #     "name": "Foo Bar",
      #     "password": "changeme",
      #     "password_confirmation": "changeme",
      #     "email": "foo@coi.com",
      #     "customer_type": "Residential",
      #     "role": "Customer"
      #   }
      # }
    # => response = HTTParty.post('#{BASE_URL}/v1/users/create', body: params)
  def create
    if create_params.present?
      c_params = create_params
      c_params[:updator_id] = current_user.id if current_user

      # country code
      loc = GEO_IP.city(request.remote_ip) rescue nil
      c_params[:country_code] = '91' if loc.present? && loc['country_code2'] == 'IN'

      user = User.new(c_params)
      
      return api_error(status: 422, errors: user.errors) unless user.valid?
      user.save

      render(
        json: Api::V1::UserSerializer.new(user),
        status: 201
      )
    else
      render nothing: true, status: :bad_request
    end
  end

  def show
    user = User.find_by_id(params[:id])
    return api_error(status: 404, errors: 'Can not find User') unless user

    user_serialized = Api::V1::UserSerializer.new(user)
    user_hash = JSON.parse(user_serialized.to_json)

    render(
      json: user_hash,
      status: 200
    )
  end

  # PUT /api/v1/users/:id
  def update
    user = User.find_by_id(params[:id])
    return api_error(status: 404, errors: 'User not found') unless user

    u_params = update_params
    u_params[:updator_id] = current_user.id if current_user

    unless user.update_attributes(u_params)
      return api_error(status: 422, errors: user.errors)
    end

    render(
      json: Api::V1::UserSerializer.new(user),
      status: 200,
      location: api_v1_user_path(user.id),
      serializer: Api::V1::UserSerializer
    )
  end

  # DELETE /api/v1/users/:id
  def destroy
    return api_error(status: 401, errors: 'You are not authorized to delete customer') unless current_user.can_delete?
    
    if current_user.utility_admin? && (@user.utility_id != current_user.utility_id)
      return api_error(status: 401, errors: 'You are not authorized to delete customer')
    end

    if current_user.super_admin?
      @user.destroy
    else
      @user.update_attribute(:deleted, true)
    end
    Tiddle.purge_old_tokens(@user) if @user

    head status: 204
  end

  def activate_account
    token = params[:ctoken]
    return api_error(status: 401, errors: 'Missing confirmation token') if token.blank?
    user = User.confirm_by_token(token)
    if user.errors.empty?
      user.activate
      NotificationMailer.welcome(user).deliver_now
      render(
        json: Api::V1::UserSerializer.new(user).to_json,
        status: 200
      )
    else
      return api_error(status: :unprocessable_entity, errors: user.errors)
    end
  end

  # URL: /api/v1/users/:id/signout
  def signout
    if current_user && Tiddle.expire_token(current_user, request)
      head status: :no_content
    else
      # Client tried to expire an invalid token
      return api_error(status: 401, errors: 'Invalid Token')
    end
  end

  # URL: POST /api/v1/users/:id/approve
  def approve
    unless @user.approved?
      @user.update_attribute(:approved, true)
      NotificationMailer.approve(@user).deliver_now
    end
    head status: 204
  end

  # URL: POST /api/v1/users/:id/unapprove
  def unapprove
    @user.update_attribute(:approved, false)
    Tiddle.purge_old_tokens(@user)
    head status: 204
  end

  def geo_location
    remote_ip =  request.remote_ip #'122.173.229.107'
    geo_location = GEO_IP.city(remote_ip) rescue nil
    geo_location = {} unless geo_location
    render(json: { location: geo_location }, status: 200)
  end

  private

    def create_params
      prepare_params
      params.require(:user).permit(
        :name,
        :email,
        :role,
        :password,
        :password_confirmation,
        :primary_mobile,
        :country_code,
        :approved,
        :updator_id,
        :addresses_attributes => [:id, :address_type, :street, :state_id, :city, :zipcode]
      ).delete_if{ |k,v| v.nil? }
    end

    def update_params
      prepare_params
      params.require(:user).permit(
        :name,
        :role,
        :primary_mobile,
        :country_code,
        :approved,
        :time_zone,
        :updator_id,
        :addresses_attributes => [
          :id, :address_type, :street, :state_id, :city, :zipcode, :_destroy
        ]
      ).delete_if{ |k,v| v.nil? }
    end

    def prepare_params
      params[:user][:addresses_attributes] = params[:user].delete(:addresses) if params[:user][:addresses].present?
      params
    end

    def find_user
      @user = User.find_by_id(params[:id])
      return api_error(status: :not_found, errors: 'User not found') unless @user
    end
  
end
