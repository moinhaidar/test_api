class Api::V1::SessionSerializer < Api::V1::BaseSerializer
  
  attributes :id, :token, :email, :name, :role

  def token
    object.authentication_token
  end

end