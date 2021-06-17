class Api::V1::PhaseConditionsController < Api::V1::ApiController
  inherit_resources
  load_and_authorize_resource unless: :skip_default_validation

  before_action :get_campaign_and_phase
  before_action :get_phase_condition, only: [:update, :destroy]

  def index
  end

  def create
  	@phase_condition = PhaseCondition.new(phase_condition_params)
    @phase_condition.phase_id = @phase.id
  	@phase_condition.save
  end

  def update
  	@phase_condition.update(phase_condition_params)
  end

  def destroy
  	@phase_condition.destroy
  	render json: { success: true }
  end

  private
    def get_campaign_and_phase
      @campaign = Campaign.find(params[:campaign_id])
      @phase = @campaign.phases.where(:id => params[:phase_id]).first
    end

    def get_phase_condition
      @phase_condition = @phase.phase_conditions.where(:id => params[:id]).first
    end

    def phase_condition_params
      params.require(:phase_condition).permit(:condition, :operator, :conditional_phase_id)
    end
end
