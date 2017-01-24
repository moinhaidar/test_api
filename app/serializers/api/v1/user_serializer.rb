class Api::V1::UserSerializer < Api::V1::BaseSerializer

  attributes :id, :name, :email, :activated, :approved, :role, :primary_mobile, :updator,
    :created_at, :updated_at

  has_many :addresses

  def created_at
    object.created_at.utc
  end

  def updated_at
    object.updated_at.utc
  end

  def updator
    object.updator.name if object.updator_id
  end
  
end
