# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Home, type: :model do
  describe 'gateway_mac_address is unique' do
    it do
      FactoryBot.create :home, gateway_mac_address: 'abc'
      expect do
        FactoryBot.create :home, gateway_mac_address: 'abc'
      end.to raise_error ActiveRecord::RecordInvalid
    end
  end

  describe 'fixes gateway_mac_address' do
    subject { home.gateway_mac_address }

    let(:home) { FactoryBot.create :home, gateway_mac_address: mac }

    describe 'lower case' do
      let(:mac) { 'abc' }

      it { is_expected.to eq 'ABC' }
    end

    describe 'lower case' do
      let(:mac) { 'a b c' }

      it { is_expected.to eq 'ABC' }
    end

    describe 'lower case' do
      let(:mac) { 'a:b:c' }

      it { is_expected.to eq 'ABC' }
    end
  end

  describe 'provisions user' do
    let(:home) { FactoryBot.create :home, gateway_mac_address: 'abc' }

    before do
      ENV['SALT'] = 'hello'
      home.provision_mqtt!
    end

    it { expect(home.mqtt_user.username).to eq home.gateway_mac_address }
    it { expect(home.mqtt_user.password).to eq '29b4c341f18e7d0fd94edc0602e5e135' }
  end

  describe 'provisions user with duplicate mac address' do

    before(:each) do
      @mac_addr = '123A456B780'
      @old_home = FactoryBot.create(:home, gateway_mac_address: @mac_addr)
      ret_val = @old_home.provision_mqtt!
      @new_home = FactoryBot.build(:home, gateway_mac_address: @mac_addr)
      @new_home.save(validate: false)
    end

    it 'destory MattUser with mac address existed' do
      @new_home.delete_by_username_mqtt_user(@mac_addr)
      expect(MqttUser.where(username: @mac_addr).count).to eq 0
    end

    it 'remove gateway_mac_address in other home' do
      @new_home.remove_mac_address_other_home(@mac_addr)
      expect(Home.where(gateway_mac_address: @mac_addr).count).to eq 1
      expect(Home.find_by_gateway_mac_address(@mac_addr).id).to eq @new_home.id
      expect(Home.find_by_id(@old_home.id).gateway_mac_address).to eq nil
    end

    it 'provision_mqtt! with gateway_mac_address existed' do
      msg = @new_home.provision_mqtt!
      mquser = MqttUser.where(home: @new_home).first
      expect(mquser).to_not eq nil
      expect(msg).not_to eq nil
    end

    it 'two time provision_mqtt! with gateway_mac_address existed' do
      @new_home.provision_mqtt!
      mquser = MqttUser.where(home: @new_home).first_or_initialize
      @new_home.provision_mqtt!
      expect(mquser.id).to_not eq nil
    end
  end
end
