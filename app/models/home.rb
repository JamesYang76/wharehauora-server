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
      out_msg = processing_provision
    end
    out_msg
  end

  def gateway
    Gateway.find_by(mac_address: gateway_mac_address)
  end

  private

  def fix_gateway_address
    return if gateway_mac_address.blank?

    self.gateway_mac_address = gateway_mac_address.gsub(/\s/, '').delete(':').upcase
  end

  def processing_provision
    out_msg = nil
    mu = MqttUser.where(home: self).first_or_initialize
    if mu.valid?
      mu.provision!
      mu.save!
    else
      out_msg = make_notification_message(mu)
    end
    out_msg
  end

  def make_notification_message(mu)
    home_name = Home.where.not(id: id).find_by(gateway_mac_address: gateway_mac_address)&.name
    return "The Mac Address #{gateway_mac_address} is already used in #{home_name} House" if home_name
    mu.errors.messages
  end
end
