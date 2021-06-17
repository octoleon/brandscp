# Company Users Controller class
#
# This class handle the requests for managing the Company Users
#
class CompanyUsersController < FilteredController
  include DeactivableController
  include UsersHelper

  respond_to :js, only: [:new, :create, :edit, :update, :time_zone_change, :time_zone_update]
  respond_to :json, only: [:index, :notifications]
  respond_to :xls, :pdf, only: :index

  helper_method :brands_campaigns_list, :viewing_profile?

  custom_actions collection: [:complete, :time_zone_change, :time_zone_update]

  before_action :validate_parent,
                only: [
                  :enable_campaigns, :disable_campaigns, :remove_campaign,
                  :select_campaigns, :add_campaign]

  skip_authorize_resource only: [:select_custom_user, :export_status, :login_as_select]

  def profile
    @company_user = current_company_user
    render :show
  end

  def login_as_select
    render layout: false
  end

  def update
    resource.user.updating_user = true if can?(:super_update, resource)
    update! do |success, failure|
      success.js do
        if resource.user.id == current_user.id
          sign_in resource.user, bypass: true
        elsif resource.invited_to_sign_up?
          resource.user.accept_invitation!
        end
        if resource.unconfirmed_email && resource.email
          flash[:info] = I18n.translate(:flash_email_confirmation, email: resource.unconfirmed_email)
        end
      end
      failure.js do
        if params[:company_user][:user_attributes][:verification_code]
          render 'verify_phone'
        end
      end
    end
  end

  def resend_email_confirmation
    resource.user.send_confirmation_instructions if resource.unconfirmed_email.present?
    render text: ''
  end

  def cancel_email_change
    return unless resource.unconfirmed_email.present?
    @unconfirmed_email = resource.unconfirmed_email
    resource.user.update_attributes(unconfirmed_email: nil, confirmation_token: nil)
  end

  def verify_phone
    return unless resource.user.phone_number.present?
    resource.user.generate_and_send_phone_verification_code
  end

  def time_zone_change
    current_user.update_column(:detected_time_zone, params[:time_zone])
  end

  def time_zone_update
    current_user.update_column(:time_zone, params[:time_zone])
    render nothing: true
  end

  def select_company
    begin
      company_user = current_user.company_users.find_by!(
        company_id: params[:company_id], active: true)
      current_user.current_company = company_user.company
      current_user.update_column(:current_company_id, company_user.company.id)
      session[:current_company_id] = company_user.company_id
    rescue ActiveRecord::RecordNotFound
      flash[:error] = 'You are not allowed login into this company'
    end
    redirect_to root_path
  end

  def select_custom_user
    begin
      if current_real_company_user.is_admin?
        user = current_company.company_users.active.find(params[:user_id])
        if params[:user_id].to_i == current_real_company_user.id
          session[:behave_as_user_id] = nil
        else
          session[:behave_as_user_id] = user.user_id
        end
      end
    rescue ActiveRecord::RecordNotFound
      flash[:error] = 'You are not allowed login as this user'
    end
    redirect_to root_path
  end

  def enable_campaigns
    return unless params[:parent_type] && params[:parent_id]

    parent_membership = resource.memberships.find_or_create_by(
      memberable_type: params[:parent_type], memberable_id: params[:parent_id])
    @parent = parent_membership.memberable
    @campaigns = @parent.campaigns
    # Delete all campaign associations assigned to this user directly under this brand/portfolio
    resource.memberships.where(
      parent_id: parent_membership.memberable.id,
      parent_type: parent_membership.memberable.class.name).destroy_all
  end

  def disable_campaigns
    if params[:parent_type] && params[:parent_id]
      membership = resource.memberships.find_by(
        memberable_type: params[:parent_type], memberable_id: params[:parent_id])
      unless membership.nil?
        resource.memberships.where(
          parent_id: membership.memberable.id,
          parent_type: membership.memberable.class.name).destroy_all
        # Assign all the campaings directly to the user
        membership.memberable.campaigns.each do |campaign|
          resource.memberships.create(memberable: campaign, parent: membership.memberable)
        end
        membership.destroy
      end
    end
    render text: 'OK'
  end

  def remove_campaign
    return unless params[:campaign_id]

    if params[:parent_type]
      membership = resource.memberships.find_by(
        memberable_type: params[:parent_type], memberable_id: params[:parent_id])
    else
      membership = nil
    end
    # If the parent is directly assigned to the user, then remove the parent and assign all the
    # current campaigns to the user
    if membership.nil?
      membership = resource.memberships.where(
        parent_type: params[:parent_type],
        parent_id: params[:parent_id],
        memberable_type: 'Campaign',
        memberable_id: params[:campaign_id]).destroy_all
    else
      membership.memberable.campaigns.where(company_id: current_company.id).each do |campaign|
        unless campaign.id == params[:campaign_id].to_i
          resource.memberships.create(memberable: campaign, parent: membership.memberable)
        end
      end
      membership.destroy
    end
  end

  def select_campaigns
    @campaigns = []
    return unless params[:parent_type] && params[:parent_id]

    return if resource.memberships.where(
      memberable_type: params[:parent_type], memberable_id: params[:parent_id]).exists?

    parent = params['parent_type'].constantize.find(params['parent_id'])
    @campaigns = parent.campaigns.active.where(company_id: current_company.id)
      .where('campaigns.id not in (?)',
             resource.campaigns.children_of(parent).pluck('campaigns.id') + [0])
  end

  def add_campaign
    return unless params[:parent_type] && params[:parent_id] && params[:campaign_id]

    @parent = params['parent_type'].constantize.find(params['parent_id'])
    campaign = current_company.campaigns.find(params[:campaign_id])
    resource.memberships.create(memberable: campaign, parent: @parent)
    @campaigns = resource.campaigns.children_of(@parent)
  end

  def export_status
    url = nil
    export = ListExport.find_by!(id: params[:download_id], company_user_id: current_company_user.id)
    url = export.download_url if export.completed? && export.file_file_name
    respond_to do |format|
      format.json do
        render json:  {
          status: export.aasm_state, progress: export.progress, url: url }
      end
    end
  end

  def notifications
    alerts = notifications_for_company_user(current_company_user)

    render json: alerts
  end

  def dismiss_alert
    current_company_user.dismiss_alert params[:name], params[:version]
    render text: ''
  end

  def resend_invite
    if resource.present? && resource.invited_to_sign_up?
      resource.user.resend_invitation
    end
    render nothing: true
  end

  protected

  def collection_to_csv
    CSV.generate do |csv|
      csv << ['FIRST NAME', 'LAST NAME', 'EMAIL', 'PHONE NUMBER', 'ROLE', 'ADDRESS 1', 'ADDRESS 2',
              'CITY', 'STATE', 'ZIP CODE', 'COUNTRY', 'TIME ZONE', 'LAST LOGIN', 'ACTIVE STATE']
      each_collection_item do |user|
        csv << [user.first_name, user.last_name, user.email, user.phone_number, user.role_name,
                user.street_address, user.unit_number, user.city, user.state, user.zip_code,
                [user.country_name].join(', '), user.time_zone, user.last_activity_at, user.active_status]
      end
    end
  end

  def permitted_params
    allowed = {
      company_user: [
        { user_attributes: [
          :id, :first_name, :last_name, :email, :phone_number,
          :password, :password_confirmation, :country, :state, :verification_code,
          :city, :street_address, :unit_number, :zip_code, :time_zone] },
        notifications_settings: []] }
    if params[:id].present? && can?(:super_update, CompanyUser.find(params[:id]))
      allowed[:company_user].concat([:role_id, { team_ids: [] }])
    end
    params.permit(allowed)[:company_user]
  end

  def roles
    @roles ||= current_company.roles
  end

  def build_state_bucket
    items = %w(Active Inactive Invited).map do |x|
      build_facet_item(label: x, id: x, name: :status, count: 1)
    end
    items = items.sort { |a, b| a[:label] <=> b[:label] }
    { label: 'Active State', items: items }
  end

  def delete_member_path(user)
    path = nil
    if params.key?(:team) && params[:team]
      path = delete_member_team_path(params[:team], member_id: user.id)
    end
    if params.key?(:campaign) && params[:campaign]
      path = delete_member_campaign_path(params[:campaign], member_id: user.id)
    end
    path
  end

  def brands_campaigns_list
    list = {}
    current_company.brand_portfolios.active.each do |portfolio|
      enabled = resource.brand_portfolios.include?(portfolio)
      campaigns = if enabled
                    portfolio.campaigns.where(company_id: current_company.id)
                  else
                    resource.campaigns.where(company_id: current_company.id).children_of(portfolio)
                  end
      list[portfolio] = { enabled: enabled, campaigns: campaigns }
    end
    current_company.brands.active.each do |brand|
      enabled = resource.brands.include?(brand)
      campaigns = if enabled
                    brand.campaigns.where(company_id: current_company.id)
                  else
                    resource.campaigns.where(company_id: current_company.id).children_of(brand)
                  end
      list[brand] = { enabled: enabled, campaigns: campaigns }
    end
    list
  end

  def validate_parent
    return if %w(BrandPortfolio Brand).include?(params[:parent_type]) || params[:parent_type].nil?
    fail CanCan::AccessDenied
  end

  def viewing_profile?
    action_name == 'profile'
  end
end
