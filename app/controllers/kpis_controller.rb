class KpisController < FilteredController
  prepend_before_action :load_campaign, only: [:new, :update, :edit, :create]
  respond_to :js, only: [:new, :create, :edit, :update]

  def create
    create! do |success, _failure|
      success.js do
        if params[:campaign_id].present?
          campaign = current_company.campaigns.find(params[:campaign_id])
          @field = campaign.add_kpi(resource)
        end
      end
    end
  end

  def index
    groups ||= Hash.new.tap do |h|
      labels = {}
      types = {}
      h['Global'] = []
      Kpi.global.form_assignable.each do |kpi|
        type = kpi.form_field_type
        types[type] ||= kpi.form_field_type.split('::')[1]
        h['Global'].push(id: kpi.id,
                         name: kpi.name,
                         type: types[type],
                         description: kpi.description,
                         options: kpi.form_field_options)
      end
      Kpi.custom(current_company).each do |kpi|
        type = kpi.form_field_type
        labels[type] ||= I18n.translate("form_builder.field_types.#{type.split('::')[1].underscore}")
        types[type] ||= kpi.form_field_type.split('::')[1]
        h[labels[type]] ||= []
        h[labels[type]].push(id: kpi.id,
                             name: kpi.name,
                             type: types[type],
                             description: kpi.description,
                             options: kpi.form_field_options)
      end
    end
    render json: groups
  end

  def load_campaign
    @campaign = current_company.campaigns.find(params[:campaign_id])
  end

  protected

  def permitted_params
    is_custom = params[:id].nil? ||
                params[:id].empty? ||
                !Kpi.global.select('id').map(&:id).include?(params[:id].to_i)
    goals_attributes = nil
    if can?(:edit_kpi_goals, @campaign)
      goals_attributes = {
        goals_attributes: [
          :id, :goalable_id, :goalable_type, :value,
          :kpis_segment_id, :kpi_id] }
    end
    segment_params = nil
    if is_custom
      if can?(:create_custom_kpis, @campaign) || can?(:edit_custom_kpi, @campaign)
        segment_params = { kpis_segments_attributes: [:id, :text, :_destroy, goals_attributes] }
      else
        segment_params = { kpis_segments_attributes: [:id, goals_attributes] }
      end
    else
      { kpis_segments_attributes: [:id, goals_attributes] }
    end
    common_params = [segment_params, goals_attributes].compact

    # Allow only certain params for global KPIs like impresssions, interactions, gender, etc
    if is_custom
      if can?(:create_custom_kpis, @campaign) || can?(:edit_custom_kpi, @campaign)
        params.permit(kpi: [:name, :description, :kpi_type, :capture_mechanism] + common_params)[:kpi]
      else
        params.permit(kpi: common_params)[:kpi]
      end
    else
      params.permit(kpi: common_params)[:kpi]
    end
  end
end
