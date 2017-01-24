# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  name                   :string(255)
#  role                   :string(255)      default("Customer")
#  email                  :string(255)      default(""), not null
#  encrypted_password     :string(255)      default(""), not null
#  primary_mobile         :string(255)
#  secondary_email        :string(255)
#  activated              :boolean          default(FALSE)
#  approved               :boolean          default(FALSE)
#  authentication_token   :string(255)
#  reset_password_token   :string(255)
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string(255)
#  last_sign_in_ip        :string(255)
#  confirmation_token     :string(255)
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#

class User < ActiveRecord::Base
  devise :database_authenticatable, :confirmable, :registerable, :recoverable, :rememberable, :trackable, :validatable, :token_authenticatable
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\-.]+\.[a-z]+\z/i

  validates :name,  presence: true, length: { maximum: 50 }
  validates :email, length: { maximum: 255 }, format: { with: VALID_EMAIL_REGEX }

  #validates :password, length: { minimum: 8 }, allow_blank: true
  validates :password_confirmation, presence: true, if: '!password.nil?'
  validates :role, presence: true
  validates :primary_mobile, uniqueness: true, length: { minimum: 10 }, allow_blank: true

  def activate
    update_attribute(:activated, true)
    update_attribute(:activated_at, Time.zone.now)
  end

  def acknowledge_token_valid?(token)
    return false if acknowledge_digest.nil?
    BCrypt::Password.new(acknowledge_digest).is_password?(token)
  end

  def reset_authentication_token
    generate_authentication_token
    self.save
  end

  def self.timezone_with_identifier
    timezones = []
    ActiveSupport::TimeZone.us_zones.sort_by{|t| t.name }.collect do |tz|
      timezones << {id: tz.name, name: "(GMT#{tz.formatted_offset}) #{tz.tzinfo.friendly_identifier} (#{tz.name})"}
    end
    timezones
  end

  private

    def validate_addresses
      errors[:base] << 'Please provide full service address' if addresses.blank?
      addresses.each do |address|
        next if address.valid?
        address.errors.full_messages.each do |msg|
          errors[:base] << "#{address.address_type} #{msg}"
        end
      end
    end

    def refine_and_set_attributes
      self.email = email.downcase
    end

    def generate_authentication_token
      loop do
        self.authentication_token = SecureRandom.base64(64).tr('+/=', 'Moi')
        break unless User.find_by(authentication_token: authentication_token)
      end
    end

    def self.new_token
      SecureRandom.urlsafe_base64
    end

    def self.digest(string)
      cost = ActiveModel::SecurePassword.min_cost ? 
        BCrypt::Engine::MIN_COST : 
        BCrypt::Engine.cost
      BCrypt::Password.create(string, cost: cost)
    end

    def prepare_acknowledgement_digest
      self.acknowledge_token  = User.new_token
      self.acknowledge_digest = User.digest(acknowledge_token)
    end

    def reject_addresses(attributes)
      [:address_type, :zipcode].any? {|field| attributes[field].blank? }
    end

    def reject_meters(attributes)
      [:account_no].any? {|field| attributes[field].blank? }
    end

    def update_customers_timezone
      self.customers.update_all(time_zone: self.time_zone) if self.utility_admin?
    end
end
