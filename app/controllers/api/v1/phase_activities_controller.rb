class Api::V1::PhaseActivitiesController < Api::V1::ApiController
  inherit_resources

  load_and_authorize_resource unless: :skip_default_validation

  before_action :get_campaign_and_phase
  before_action :get_phase_activity, only: [:update, :destroy]

  def index
  end

  def create
  	@phase_activity = PhaseActivity.new(phase_activity_params)
    @phase_activity.phase_id = @phase.id
  	@phase_activity.save
    save_phase_activity_conditions(@phase_activity, params[:phase_activity_conditions])
  end

  def update
  	@phase_activity.update(phase_activity_params)
    save_phase_activity_conditions(@phase_activity, params[:phase_activity_conditions])
  end

  def destroy
  	@phase_activity.destroy
  	render json: { success: true }
  end

  private
    def get_campaign_and_phase
      @campaign = Campaign.find(params[:campaign_id])
      @phase = @campaign.phases.where(:id => params[:phase_id]).first
    end

    def get_phase_activity
      @phase_activity = @phase.phase_activities.where(:id => params[:id]).first
    end

    def save_phase_activity_conditions(phase_activity, phase_activity_conditions)
      phase_activity_save = false
      if !phase_activity_conditions.blank?
        phase_activity_conditions.each do |condition|
          data = condition[1]
          if data[:id].blank?
            authorize! :create, Activity
            pac = PhaseActivityCondition.new({ conditional_phase_activity_id: data[:conditional_phase_activity_id], condition: data[:condition], operator: data[:operator] })
            phase_activity.phase_activity_conditions << pac
            phase_activity_save = true
          else
            authorize! :update, Activity
            pac = PhaseActivityCondition.find(data[:id])
            pac.update({ conditional_phase_activity_id: data[:conditional_phase_activity_id], condition: data[:condition], operator: data[:operator] })
          end
        end
      end
      if phase_activity_save
        phase_activity.save
      end
    end

    def phase_activity_params
      params.require(:phase_activity).permit(:display_name, :required, :order, :activity_type, :activity_id, :due_date)
    end
end
