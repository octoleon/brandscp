class Api::V1::PhasesController < Api::V1::ApiController
  inherit_resources

  load_and_authorize_resource unless: :skip_default_validation

  before_action :get_campaign
  before_action :get_phase, only: [:update, :destroy]

  def index
  end

  def create
  	@phase = Phase.new(phase_params)
  	@phase.campaign_id = @campaign.id
  	@phase.save
    save_phase_conditions(@phase, params[:phase_conditions])
  end

  def update
  	@phase.update(phase_params)
    save_phase_conditions(@phase, params[:phase_conditions])
  end

  def destroy
  	@phase.destroy
  	render json: { success: true }
  end

  private

  def get_campaign
    @campaign = Campaign.find(params[:campaign_id])
  end

  def get_phase
    @phase = @campaign.phases.where(:id => params[:id]).first
  end

  def phase_params
    params.require(:phase).permit(:name, :description, :requires_approval, :order, :conditional_status, :conditional_action)
  end

  # v1.0 TODO: clean this up. Why is this so dirty?
  def save_phase_conditions(phase, phase_conditions)
    phase_save = false
    if !phase_conditions.blank?
      phase_conditions.each do |condition|
        data = condition[1]
        if data[:id].blank?
          authorize! :create, Campaign
          pc = PhaseCondition.new({ conditional_phase_id: data[:conditional_phase_id], condition: data[:condition], operator: data[:operator] })
          phase.phase_conditions << pc
          phase_save = true
        else
          authorize! :update, Campaign
          pc = PhaseCondition.find(data[:id])
          pc.update({ conditional_phase_id: data[:conditional_phase_id], condition: data[:condition], operator: data[:operator] })
        end
      end
    end
    if phase_save
      phase.save
    end
  end
end
