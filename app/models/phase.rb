class Phase < ActiveRecord::Base
  include AASM
  
  enum conditional_action: [:is_lock, :is_unlock] # using the "is" prefix because lock, all, none are all reserved rails keywords
  enum conditional_status: [:is_all, :is_any, :is_none]
  belongs_to :campaign
  has_many :phase_activities, -> { order 'phase_activities.order ASC' }
  has_many :phase_conditions


  aasm do
    state :unsent, initial: true
    state :submitted
    state :approved
    state :rejected

    event :submit, before: -> { self.submitted_at = DateTime.now } do
      transitions from: [:unsent, :rejected], to: :submitted, guard: :valid_to_submit?
    end

    event :approve, before: -> { self.approved_at = DateTime.now } do
      transitions from: :submitted, to: :approved
    end

    event :unapprove, before: -> { self.approved_at = nil } do
      transitions from: :approved, to: :submitted
    end

    event :reject, before: -> { self.rejected_at = DateTime.now } do
      transitions from: :submitted, to: :rejected
    end
  end

  def locked?(event)
    conditional_action == 'is_lock' && conditions_met(event)
  end

  def unlocked?(event)
    !locked?(event)
  end

  def complete?(event)
    true
  end

  def is_empty?(event)
    true
  end

  def phase_status
    (aasm_state.nil? ? 'unsent' : aasm_state).capitalize
  end

  def conditions_met(event)
    arr = []
    self.phase_conditions.each do |condition|
      if condition.is_date_condition?
        time_to_check = Time.now + condition[:condition].days
        d = event.start_at if condition.is_event_start_condition?
        d = event.end_at if condition.is_event_end_condition?
        case condition.operator
        when 'less_than'
          arr << (d < time_to_check)
        when 'greater_than'
          arr << (d > time_to_check)
        else # equals
          arr << (d == time_to_check)
        end
      else
        case condition.condition
        when 'complete'
          arr << condition.conditional_phase.complete?(event)
        when 'locked'
          arr << condition.conditional_phase.locked?(event)
        when 'empty'
          arr << condition.conditional_phase.is_empty?(event)
        when 'approved', 'rejected'
          arr << condition.conditional_phase.phase_status == condition.condition.capitalize
        else 
          arr << false
        end
      end
    end

    true_count = arr.select { |b| b }.count
    case conditional_status
    when 'is_none'
      true_count == 0
    when 'is_any'
      true_count > 0
    else
      true_count == arr.count
    end

    return true
  end
end
