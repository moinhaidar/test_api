class Api::V1::BaseSerializer < ActiveModel::Serializer

  def created_at
    object.created_at.in_time_zone.to_s(:db) if object.created_at
  end

  def updated_at
    object.updated_at.in_time_zone.to_s(:db) if object.created_at
  end
  
end
