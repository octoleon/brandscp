attributes :id, :activity_id, :activity_type, :order, :display_name, :required, :settings, :due_date, :conditional_action, :conditional_status, :created_at, :updated_at

child :phase_activity_conditions do
  extends "api/v1/phase_activity_conditions/phase_activity_condition"
end