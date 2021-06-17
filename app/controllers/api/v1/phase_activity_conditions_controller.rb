class Api::V1::PhaseActivityConditionsController < Api::V1::ApiController
  inherit_resources

  load_and_authorize_resource unless: :skip_default_validation

  before_action :get_campaign_and_phase_and_phase_activity
  before_action :get_phase_activity_condition, only: [:update, :destroy]

  def index
  end

  def create
  	@phase_activity_condition = PhaseActivityCondition.new(phase_activity_condition_params)
    @phase_activity_condition.phase_activity_id = @phase_activity.id
  	@phase_activity_condition.save
  end

  def update
  	@phase_activity_condition.update(phase_activity_condition_params)
  end

  def destroy
  	@phase_activity_condition.destroy
  	render json: { success: true }
  end

  private
    def get_campaign_and_phase_and_phase_activity
      @campaign = Campaign.find(params[:campaign_id])
      @phase = @campaign.phases.where(:id => params[:phase_id]).first
      @phase_activity = @phase.phase_activities.where(:id => params[:phase_activity_id]).first
    end

    def get_phase_activity_condition
      @phase_activity_condition = @phase_activity.phase_activity_conditions.where(:id => params[:id]).first
    end

    def phase_activity_condition_params
      params.require(:phase_activity_condition).permit(:condition, :operator, :conditional_phase_activity_id)
    end
end
