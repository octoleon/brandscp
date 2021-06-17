class PhaseActivityCondition < ActiveRecord::Base
	enum condition: [:complete, :locked, :empty, :approved, :rejected]
	enum operator: [:is, :is_not]

	belongs_to :phase_activity
end
