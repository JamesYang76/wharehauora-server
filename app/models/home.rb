# frozen_string_literal: true

class Home < ApplicationRecord
  belongs_to :owner, class_name: 'User'
  belongs_to :home_type, optional: true

  has_one :mqtt_user

  has_many :rooms
  has_many :messages, through: :sensors

  has_many :sensors
  has_many :readings, through: :rooms

  has_many :home_viewers

  has_many :users, through: :home_viewers

  has_many :invitations

  scope(:is_public?, -> { where(is_public: true) })

  validates :name, presence: true
  validates :owner, presence: true
  before_validation :fix_gateway_address
  validates :gateway_mac_address, uniqueness: true,
                                  allow_blank: true,
                                  format: { with: /\A[A-F0-9]*\z/, message: 'should have only letters A-F and numbers' }

  def provision_mqtt!
    out_msg = nil
    return if gateway_mac_address.blank?
    ActiveRecord::Base.transaction do
      mu = MqttUser.where(home: self).first_or_initialize
      out_msg = handle_invalid_mqtt_user(gateway_mac_address) unless mu.valid?
      mu.provision!
      mu.save!
    end
    out_msg
  end

  def handle_invalid_mqtt_user(gateway_mac_address)
    delete_by_username_mqtt_user(gateway_mac_address)
    remove_mac_address_other_home(gateway_mac_address)
    "The Mac Address #{gateway_mac_address} is reused"
  end

  def remove_mac_address_other_home(mac_addr)
    Home.where.not(id: id).where(gateway_mac_address: mac_addr).update(gateway_mac_address: nil)
  end

  def delete_by_username_mqtt_user(mac_addr)
    MqttUser.where(username: mac_addr).destroy_all
  end

  def gateway
    Gateway.find_by(mac_address: gateway_mac_address)
  end

  private

  def fix_gateway_address
    return if gateway_mac_address.blank?

    self.gateway_mac_address = gateway_mac_address.gsub(/\s/, '').delete(':').upcase
  end
end
