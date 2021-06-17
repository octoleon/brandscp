# Campaigns Controller class
#
# This class handle the requests for managing the Campaigns
#
class CampaignsController < FilteredController
  respond_to :js, only: [:new, :create, :edit, :update, :new_date_range]
  respond_to :json, only: [:show, :update]
  respond_to :xls, :pdf, only: :index

  before_action :search_params, only: [:index]

  include DeactivableController

  # This helper provide the methods to add/remove campaigns members to the event
  extend TeamMembersHelper

  # This helper provide the methods to export HTML to PDF
  include ExportableForm

  # Handle the noticaitions for new campaigns
  include NotificableController

  notifications_scope -> { current_company_user.notifications.new_campaigns }

  skip_authorize_resource only: :tab

  layout false, only: :kpis

  def update
    update! do |success, failure|
      success.js { render }
      success.json { render json: { result: 'OK' } }
      failure.json do
        render json: {
          result: 'KO', message: resource.errors.full_messages.join('<br />') }
      end
    end
  end

  def find_similar_kpi
    search = Sunspot.search(Kpi) do
      keywords(params[:name]) do
        fields(:name)
      end
      with(:company_id, [-1, current_company.id])
    end
    render json: search.results
  end

  def remove_kpi
    @field = resource.form_fields.where(kpi_id: params[:kpi_id]).first
    @field.destroy
  end

  def event_dates
    render json: resource.event_dates
  end

  def add_kpi
    if resource.form_fields.where(kpi_id: params[:kpi_id]).count == 0
      @kpi = Kpi.global_and_custom(current_company).find(params[:kpi_id])
      @field = resource.add_kpi(@kpi)
    else
      render text: ''
    end
  end

  def select_kpis
    @kpis = (
      Kpi.campaign_assignable(resource) +
      current_company.activity_types.where.not(id: resource.activity_type_ids).active
    ).sort_by(&:name)
  end

  def remove_activity_type
    activity_type = current_company.activity_types.find(params[:activity_type_id])
    if resource.activity_types.include?(activity_type)
      resource.activity_types.delete(activity_type)
    else
      render text: ''
    end
  end

  def add_activity_type
    if resource.activity_types.exists?(params[:activity_type_id])
      render text: ''
    else
      activity_type = current_company.activity_types.find(params[:activity_type_id])
      resource.activity_types << activity_type
    end
  end

  def new_date_range
    @date_ranges = current_company.date_ranges.active
      .where('date_ranges.id not in (?)', resource.date_range_ids + [0])
  end

  def add_date_range
    return if resource.date_ranges.exists?(params[:date_range_id])
    resource.date_ranges << current_company.date_ranges.find(params[:date_range_id])
  end

  def delete_date_range
    date_range = resource.date_ranges.find(params[:date_range_id])
    resource.date_ranges.delete(date_range)
  end

  def new_day_part
    @day_parts = current_company.day_parts.active
      .where('day_parts.id not in (?)', resource.day_part_ids + [0])
  end

  def add_day_part
    return if resource.day_parts.exists?(params[:day_part_id])
    resource.day_parts << current_company.day_parts.find(params[:day_part_id])
  end

  def delete_day_part
    day_part = resource.day_parts.find(params[:day_part_id])
    resource.day_parts.delete(day_part)
  end

  def tab
    authorize! "view_#{params[:tab]}".to_sym, resource
    render layout: false
  end

  protected

  def collection_to_csv
    CSV.generate do |csv|
      csv << ['NAME', 'DESCRIPTION', 'FIRST EVENT', 'LAST EVENT', 'ACTIVE STATE']
      each_collection_item do |campaign|
        csv << [campaign.name, campaign.description, campaign.first_event_date, campaign.last_event_date, campaign.status]
      end
    end
  end

  # This is used for exporting the form in PDF format. Initializes
  # a new activity for the current campaign
  def fieldable
    @fieldable ||= resource.events.build
  end

  def pdf_form_file_name
    "#{resource.name.parameterize}-#{Time.now.strftime('%Y%m%d%H%M%S')}"
  end

  def permitted_params
    p = [:name, :start_date, :end_date, :description, :color, :brands_list, { brand_portfolio_ids: [] }]
    if can?(:view_event_form, Campaign)
      p.push(
        survey_brand_ids: [],
        form_fields_attributes: [
          :id, :name, :field_type, :ordering, :required, :multiple, :_destroy, :kpi_id,
          { settings: [:description, :range_min, :range_max, :range_format, :campaigns,
                       :operation, :calculation_label, { disabled_segments: [] }] },
          { options_attributes: [:id, :name, :_destroy, :ordering] },
          { statements_attributes: [:id, :name, :_destroy, :ordering] }])
    end
    attrs = params.permit(campaign: p)[:campaign].tap do |whitelisted|
      if params[:campaign] && params[:campaign].key?(:modules) && can?(:view_event_form, Campaign)
        whitelisted[:modules] = params[:campaign][:modules]
      end
    end

    if attrs && attrs[:survey_brand_ids].present? && attrs[:survey_brand_ids].any?
      normalize_brands attrs[:survey_brand_ids]
    end

    # Workaround to deal with jQuery not sending empty arrays
    if attrs && attrs[:modules].present? && attrs[:modules].key?('empty')
      attrs[:modules] = {}
    end

    attrs
  end

  def normalize_brands(brands)
    return if brands.empty?

    brands.each_with_index do |b, index|
      unless b.is_a?(Integer) || b =~ /\A[0-9]+\z/
        b = current_company.brands.where('lower(name) = ?', b.downcase).pluck(:id).first ||
            current_company.brands.create(name: b).id
      end
      brands[index] = b.to_i
    end
  end
end
