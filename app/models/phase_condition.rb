class PhaseCondition < ActiveRecord::Base
	enum condition: { 
		day_of: 0, 
		one_before: 1, two_before: 2, three_before: 3, four_before: 4, five_before: 5, six_before: 6, seven_before: 7, 
		one_past: -1, two_past: -2, three_past: -3, four_past: -4, five_past: -5, six_past: -6, seven_past: -7, 
		complete: 10, locked: 11, empty: 12, approved: 13,  rejected: 14 }
	enum operator: [:is, :is_not, :less_than, :greater_than, :equals]

	belongs_to :phase

	def is_date_condition?
		is_event_start_condition? || is_event_end_condition?
	end

	def is_event_start_condition?
		conditional_phase_id == -1
	end

	def is_event_end_condition?
		conditional_phase_id == -2
	end

	def conditional_phase
		Phase.find(conditional_phase_id)
	end
end
