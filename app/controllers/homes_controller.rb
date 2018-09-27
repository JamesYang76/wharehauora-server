# frozen_string_literal: true

class HomesController < ApplicationController
  before_action :authenticate_user!, except: :show
  before_action :set_home, only: %i[show edit destroy update]
  respond_to :html

  def index
    authorize :home
    @homes = policy_scope(Home)
             .includes(:home_type, :owner)
             .order(:name)
             .paginate(page: params[:page])
    respond_with(@homes)
  end

  def show
    redirect_to home_rooms_path(@home)
  end

  def new
    @home = Home.new
    authorize @home
    respond_with(@home)
  end

  # rubocop:disable Metrics/AbcSize
  def create
    @home = Home.new(home_params)
    authorize @home
    invite_new_owner
    @home.save
    respond_with(@home, location: home_rooms_path(@home))
  end
  # rubocop:enable Metrics/AbcSize

  def edit
    @home_types = HomeType.all
    @home_suburb_name = @home.suburb.name if @home.suburb

    respond_with(@home)
  end

  def update
    # suburb = find_or_create_suburb home_params['home_suburb_name']

    # params[:home].delete :home_suburb_name

    # @home.update(home_params.merge(suburb_id: suburb ? suburb.id : nil))
    # @home.save!
    if @home.update(home_params)
      @home.provision_mqtt! if @home.gateway_mac_address.present?
    end
    respond_with(@home)
  end

  def destroy
    @home.destroy
    respond_with(@home)
  end

  private

  def invite_new_owner
    if current_user.janitor?
      owner = User.find_by(owner_params)
      @home.owner = owner || User.invite!(owner_params)
    else
      @home.owner = current_user
    end
  end

  def parse_dates
    @day = params[:day]
    @day = Time.zone.today if @day.blank?
  end

  def home_params
    params.require(:home).permit(:name, :is_public, :home_type_id, :gateway_mac_address)
  end

  def owner_params
    params.require('owner').permit('email')
  end

  def set_home
    @home = policy_scope(Home).find(params[:id])
    authorize @home
  end

  def find_or_create_suburb(name)
    suburb = nil

    if name.present?
      suburb = Suburb.find_by(name: name)
      suburb = Suburb.create!(name: name) unless suburb
    end

    suburb
  end
end
