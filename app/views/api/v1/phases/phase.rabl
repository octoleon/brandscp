attributes :id, :name, :description, :requires_approval, :order, :campaign_id, :conditional_action, :conditional_status, :created_at, :updated_at

child :phase_activities do
  extends "api/v1/phase_activities/phase_activity"
end

child :phase_conditions do
  extends "api/v1/phase_conditions/phase_condition"
end