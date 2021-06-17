module EventPhases
  extend ActiveSupport::Concern

  def phases
    @phases ||= {
      current_phase: current_phase,
      next_step: next_step,
      phases: get_phases
    }
  end

  def get_phases
    phases = {}
    self.campaign.phases.each do |phase|
      a = []
      phase.phase_activities.each do |phase_activity|
        a.push(id: phase_activity.identifier, title: phase_activity.display_name, complete: phase_activity.complete?, required: phase_activity.required)
      end
      phases[phase.name.to_sym] = { activities: a, phase_model: phase }
    end
    phases
  end

  def current_phase
    self.campaign.phases.each_with_index do |phase, i|
      puts '##' * 25
      puts phase.inspect
      puts phase.conditions_met(self)
      if !phase.conditions_met(self)
        if i == 0
          phase.name.to_sym
        else
          self.campaign.phases[i-1].name.to_sym
        end
      end
    end
    self.campaign.phases.last.name.to_sym
  end

  # v1.0 TODO: what is this actually used for?
  def next_step
    # { plan: plan_phases,
    #   execute: api_execute_phase,
    #   results: results_phases }[current_phase].find { |p| p[:complete] == false }
    {}
  end

  def expenses_complete?
    module_have_items_and_in_valid_range?('expenses', event_expenses.count)
  end

  def photos_complete?
    module_have_items_and_in_valid_range?('photos', photos.active.count)
  end

  def comments_complete?
    module_have_items_and_in_valid_range?('comments', comments.count)
  end

  def module_items_valid?(module_name, count)
    min = campaign.module_setting(module_name, 'range_min')
    max = campaign.module_setting(module_name, 'range_max')
    (min.blank? || (count >= min.to_i)) && (max.blank? || (count <= max.to_i))
  end

  def module_required?(module_name)
    min = campaign.module_setting(module_name, 'range_min')
    max = campaign.module_setting(module_name, 'range_max')
    !min.blank? || !max.blank?
  end

  # A module is considered complete if there are not range validation defined
  # and have at least one item. If there are range validations, then it's completed
  # only if those are met.
  def module_have_items_and_in_valid_range?(module_name, count)
    (module_range_settings_empty?(module_name) && count > 0) ||
      (!module_range_settings_empty?(module_name) &&
       module_items_valid?(module_name, count) &&
       (count > 0 || module_range_has_min?(module_name)))
  end

  def module_range_settings_empty?(module_name)
    campaign.module_setting(module_name, 'range_min').blank? &&
      campaign.module_setting(module_name, 'range_max').blank?
  end

  def module_range_has_min?(module_name)
    !campaign.module_setting(module_name, 'range_min').blank?
  end
end
