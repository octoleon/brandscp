class PhaseActivity < ActiveRecord::Base
	belongs_to :phase
	serialize :settings

	has_many :phase_activity_conditions

	def identifier
		mappings = [nil, 'expenses', 'media', 'surveys', 'comments', 'tasks', 'contacts', 'documents', 'attendance']
		return mappings[self.activity_id] if self.activity_type == 'module'
		return 'custom-activity-form-' + self.activity_id.to_s
	end

	def complete?
		
	end
end