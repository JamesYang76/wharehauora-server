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
    let!(:home) { FactoryBot.build(:home, gateway_mac_address: '123A456B780') }
    let!(:new_home) { FactoryBot.build(:home, gateway_mac_address: '123A456B780') }

    before do
      home.save(validate: false)
      new_home.save(validate: false)
      home.provision_mqtt!
    end

    it 'processing_provision with gateway_mac_address existed' do
      message = new_home.send(:processing_provision)
      expect(message).not_to eq nil
    end

    it 'provision_mqtt! with gateway_mac_address existed' do
      message = new_home.provision_mqtt!
      expect(message).not_to eq nil
    end
  end
end
