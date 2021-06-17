(function($) {
	'use strict';

	var Views = {};

	Views.newPhaseForm = function(phase, formClosed, all_phases) {
		var s = '<div class="builder-block phase-block %closedClass%" %phaseId%> \
              <div class="block-header"> \
                <div class="block-counter phase-counter">%phaseCount%</div> \
                <div class="block-title-wrapper">Phase: <span class="phase-title">%phaseTitle%</span> \
                  <div class="block-actions"> \
                    <i class="icon icon-trash phase-delete"></i> \
                  </div> \
                </div> \
              </div> \
              <div class="block-info" %hideIfClosed%> \
                <ul class="nav nav-tabs"> \
                  <li class="active"><a data-target=".settings">Basic Settings</a></li> \
                  <li><a data-target=".logic">Conditional Logic</a></li> \
                </ul> \
                <div class="tab-content"> \
                  <div class="tab-pane settings active"> \
                    <label>Name</label> \
                    <input type="text" class="phase-name-input" value="%phaseTitle%" /> \
                    <label>Description</label> \
                    <textarea type="text" class="phase-description-textarea">%phaseDescription%</textarea> \
                    <label><input type="checkbox" class="phase-requires-approval-checkbox" %phaseReqApproval%> Requires Approval</label> \
                  </div> \
                  <div class="tab-pane logic"> \
                    <p>Please use the following to setup skip and conditional logic for your phases:</p> \
                    <div class="phase-logic"> \
                      <select class="action-select"> \
                        <option value="is_lock">Lock</option> \
                        <option value="is_unlock">Unlock</option> \
                      </select> \
                      this phase if \
                      <select class="status-select"> \
                        <option value="is_all">All</option> \
                        <option value="is_any">Any</option> \
                        <option value="is_none">None</option> \
                      </select> \
                      of the following criteria is met: <br>\
                    </div> \
                    <div class="phase-conditions-list"> \
                    </div> \
                    <a class="add-phase-condition"> \
                      <i class="icon-plus-sign"></i> Add Logic \
                    </a> \
                  </div> \
                </div> \
                <div class="btn-wrapper"> \
                  <button class="btn btn-primary btn-save-phase">Save</button> \
                  <button class="btn btn-default btn-cancel-phase">Cancel</button> \
                </div> \
              </div> \
              <div class="phase-activities" %showIfPhaseIsSaved%> \
                <div class="phase-activity-list"></div> \
                <div class="phase-activity-dropzone">Drag & Drop An Activity Here</div> \
              </div> \
            </div>';

    var $el = $(s.replace(/%phaseId%/g, phase.id ? 'data-id="' + phase.id + '"' : '')
            .replace(/%phaseCount%/g, phase.order)
            .replace(/%phaseTitle%/g, phase.name)
            .replace(/%phaseDescription%/g, phase.description ? phase.description : '')
            .replace(/%phaseReqApproval%/g, phase.requires_approval ? 'checked' : '')
            .replace(/%closedClass%/g, formClosed ? 'closed' : '')
            .replace(/%hideIfClosed%/g, formClosed ? 'style="display: none;"' : '')
            .replace(/%showIfPhaseIsSaved%/g, phase.id ? '' : 'style="display: none;"'));

    if(phase.conditional_action) {
      $el.find('.action-select').val(phase.conditional_action);
    }
    if(phase.conditional_status) {
      $el.find('.status-select').val(phase.conditional_status);
    }
    $el.data('model', phase);

    // Conditions UI
    if(phase.phase_conditions && phase.phase_conditions.length > 0) {
      $el.find('.phase-logic').show();
      for(var i = 0; i < phase.phase_conditions.length; i++) {
        $el.find('.phase-conditions-list').append(Views.PhaseConditionalItem(phase.phase_conditions[i], all_phases));
      }
    }

    if(phase.phase_activities) {
      // Add each Activity to Phase
      for(var i = 0; i < phase.phase_activities.length; i++) {
        $el.find('.phase-activity-list').append(Views.ModuleBuilderBlock(phase.phase_activities[i], true, phase.phase_activities));
      }
    }
    return $el;
	}

  Views._ModuleMinMaxSettings = function() {
    var s = '<label>Min</label> \
            <input type="text" placeholder="Min" class="activity-min-input" /> \
            <label>Max</label> \
            <input type="text" placeholder="Max" class="activity-max-input" />';
    return s;
  }

  Views._ModuleExpensesSettings = function(module) {
    var s = Views._ModuleMinMaxSettings() +
            '<label><input type="checkbox" %expenseReceiptRequired> Receipt Required</label> \
            <label>Categories</label> \
            <input type="text" placeholder="Categories" class="activity-expenses-categories-input" />';
    return s;
  }

  Views._ModuleSurveysSettings = function(module) {
    var s = '<label>Brands</label> \
            <select class="builder-brands-select"></select>';
    return s;
  }

  Views._ModuleDefaultSettings = function(module) {
    var s = '<label>Display Name</label> \
            <input type="text" class="activity-display-name-input" value="%activityDisplayName%" /> \
            <label><input type="checkbox" class="activity-required-checkbox" %activityRequired%> Required</label> \
            <label>Due Date</label> \
            <input type="text" class="activity-due-date-datepicker" value="%activityDueDate%" />';
    return s.replace(/%activityDisplayName%/g, module.display_name)
            .replace(/%activityRequired%/g, module.required ? 'checked' : '')
            .replace(/%activityDueDate%/g, module.due_date ? module.due_date : '');
  }

  Views.ModuleBuilderBlock = function(activity, formClosed, all_activities_in_phase) {
    var s = '<div class="builder-block activity-block %closedClass%" %phaseActivityId% data-activitytype="%activityType%" data-activityid="%activityId%"> \
              <div class="block-header"> \
                <div class="block-counter activity-counter">%activityCount%</div> \
                <div class="block-title-wrapper">%activityDisplayName% \
                  <div class="block-actions"> \
                    <i class="icon icon-trash activity-delete"></i> \
                  </div> \
                </div> \
              </div> \
              <div class="block-info" %hideIfClosed%> \
                <ul class="nav nav-tabs"> \
                  <li class="active"><a data-target=".settings">Basic Settings</a></li> \
                  <li><a data-target=".logic">Conditional Logic</a></li> \
                  <li><a data-target=".goals">Goals</a></li> \
                </ul> \
                <div class="tab-content"> \
                  <div class="tab-pane settings active">';
        s +=        Views._ModuleDefaultSettings(activity);
        if(activity.activity_type == 'module') {
          if(activity.activity_id == 1) { // Expenses
            s += Views._ModuleExpensesSettings(activity);
          }
          else if(activity.activity_id == 2 || activity.activity_id == 4) { // Media or Comments
            s += Views._ModuleMinMaxSettings();
          }
        }
        s +=      '</div> \
                  <div class="tab-pane logic"> \
                    <p>Please use the following to setup skip and conditional logic for your activities:</p> \
                    <div class="activity-logic"> \
                      <select class="action-select"> \
                        <option value="is_lock">Lock</option> \
                        <option value="is_unlock">Unlock</option> \
                      </select> \
                      this activity if \
                      <select class="status-select"> \
                        <option value="is_all">All</option> \
                        <option value="is_any">Any</option> \
                        <option value="is_none">None</option> \
                      </select> \
                      of the following criteria is met: <br>\
                    </div> \
                    <div class="activity-conditions-list"> \
                    </div> \
                    <a class="add-activity-condition"> \
                      <i class="icon-plus-sign"></i> Add Logic \
                    </a> \
                  </div> \
                  <div class="tab-pane goals"> \
                    <p>Please use the following to setup goals for your activities:</p> \
                    <div class="activity-goals-list"> \
                      <div class="activity-goals-list-header"> \
                        <span>KPI</span> \
                        <span>Operation</span> \
                        <span>Field</span> \
                      </div> \
                    </div> \
                    <a class="add-activity-goal"> \
                      <i class="icon-plus-sign"></i> Add Goal \
                    </a> \
                  </div> \
                </div> \
                <div class="btn-wrapper"> \
                  <button class="btn btn-primary btn-save-activity">Save</button> \
                  <button class="btn btn-default btn-cancel-activity">Cancel</button> \
                </div> \
              </div> \
            </div>';
    var $el = $(s.replace(/%phaseActivityId%/g, activity.id ? 'data-id="' + activity.id + '"' : '')
                .replace(/%activityType%/g, activity.activity_type)
                .replace(/%activityId%/g, activity.activity_id)
                .replace(/%activityCount%/g, activity.order)
                .replace(/%activityDisplayName%/g, activity.display_name)
                .replace(/%closedClass%/g, formClosed ? 'closed' : '')
                .replace(/%hideIfClosed%/g, formClosed ? 'style="display: none;"' : ''));

    if(activity.conditional_action) {
      $el.find('.action-select').val(activity.conditional_action);
    }
    if(activity.conditional_status) {
      $el.find('.status-select').val(activity.conditional_status);
    }
    $el.data('model', activity);

    // Conditions UI
    if(activity.phase_activity_conditions && activity.phase_activity_conditions.length > 0) {
      $el.find('.activity-logic').show();
      for(var i = 0; i < activity.phase_activity_conditions.length; i++) {
        $el.find('.activity-conditions-list').append(Views.ActivityConditionalItem(activity.phase_activity_conditions[i], all_activities_in_phase));
      }
    }

    return $el;
  }

  Views.PhaseConditionalItem = function(phaseCondition, phasesList) {
    var s = '<div class="phase-conditional-item" %phaseConditionId%> \
              <select class="phases-select"> \
                <option>Select One</option> \
                <option value="-1">[EVENT START]</option> \
                <option value="-2">[EVENT END]</option>';
    for(var i = 0; i < phasesList.length; i++) {
        s +=    '<option value="' + phasesList[i].id + '">' + phasesList[i].name + '</option>';
    }
        s +=  '</select> \
              <select class="operator-select"> \
                <option>Select One</option> \
                <option value="is">Is</option> \
                <option value="is_not">Is Not</option> \
                <option value="less_than" class="date %ifOptionIsDate%"><</option> \
                <option value="greater_than" class="date %ifOptionIsDate%">></option> \
                <option value="equals" class="date %ifOptionIsDate%">=</option> \
              </select> \
              <select class="condition-select"> \
                <option>Select One</option> \
                <option value="complete">Complete</option> \
                <option value="locked">Locked</option> \
                <option value="empty">Not Started / Empty</option> \
                <option value="approved">Approved</option> \
                <option value="rejected">Rejected</option> \
                <option value="day_of" class="date %ifOptionIsDate%">The day of</option> \
                <option value="one_before" class="date %ifOptionIsDate%">1 day before</option> \
                <option value="two_before" class="date %ifOptionIsDate%">2 days before</option> \
                <option value="three_before" class="date %ifOptionIsDate%">3 days before</option> \
                <option value="four_before" class="date %ifOptionIsDate%">4 days before</option> \
                <option value="five_before" class="date %ifOptionIsDate%">5 days before</option> \
                <option value="six_before" class="date %ifOptionIsDate%">6 days before</option> \
                <option value="seven_before" class="date %ifOptionIsDate%">7 days before</option> \
                <option value="one_past" class="date %ifOptionIsDate%">1 day past</option> \
                <option value="two_past" class="date %ifOptionIsDate%">2 days past</option> \
                <option value="three_past" class="date %ifOptionIsDate%">3 days past</option> \
                <option value="four_past" class="date %ifOptionIsDate%">4 days past</option> \
                <option value="five_past" class="date %ifOptionIsDate%">5 days past</option> \
                <option value="six_past" class="date %ifOptionIsDate%">6 days past</option> \
                <option value="seven_past" class="date %ifOptionIsDate%">7 days past</option> \
              </select> \
              <a class="remove-phase-conditional-item"><i class="icon-minus-rounded"></i></a> \
            </div>';

    var $el = $(s.replace(/%phaseConditionId%/g, phaseCondition.id ? 'data-id="' + phaseCondition.id + '"' : '')
                  .replace(/%ifOptionIsDate%/g, phaseCondition.conditional_phase_id && (phaseCondition.conditional_phase_id == -1 || phaseCondition.conditional_phase_id == -2) ? '' : 'hide'));

    if(phaseCondition.conditional_phase_id) {
      $el.find('.phases-select').val(phaseCondition.conditional_phase_id);
    }
    if(phaseCondition.operator) {
      $el.find('.operator-select').val(phaseCondition.operator);
    }
    if(phaseCondition.condition) {
      $el.find('.condition-select').val(phaseCondition.condition);
    }
    return $el;
  }

  Views.ActivityConditionalItem = function(activity_condition, activitiesList) {
    var s = '<div class="activity-conditional-item" %activityConditionId%> \
              <select class="activities-select"> \
                <option>Select One</option>';
    for(var i = 0; i < activitiesList.length; i++) {
        s +=    '<option value="' + activitiesList[i].id + '">' + activitiesList[i].display_name + '</option>';
    }
        s +=  '</select> \
              <select class="operator-select"> \
                <option>Select One</option> \
                <option value="is">Is</option> \
                <option value="is_not">Is Not</option> \
              </select> \
              <select class="condition-select"> \
                <option>Select One</option> \
                <option value="complete">Complete</option> \
                <option value="locked">Locked</option> \
                <option value="unlocked">Unlocked</option> \
                <option value="empty">Not Started / Empty</option> \
                <option value="approved">Approved</option> \
                <option value="rejected">Rejected</option> \
              </select> \
              <a class="remove-activity-conditional-item"><i class="icon-minus-rounded"></i></a> \
            </div>';

    var $el = $(s.replace(/%activityConditionId%/g, activity_condition.id ? 'data-id="' + activity_condition.id + '"' : ''));

    if(activity_condition.conditional_phase_activity_id) {
      $el.find('.activities-select').val(activity_condition.conditional_phase_activity_id);
    }
    if(activity_condition.operator) {
      $el.find('.operator-select').val(activity_condition.operator);
    }
    if(activity_condition.condition) {
      $el.find('.condition-select').val(activity_condition.condition);
    }
    return $el;
  }

  Views.ActivityGoalItem = function(activitiesList) {
    var s = '<div class="activity-conditional-item"> \
              <select class="kpis-select"> \
                <option>Select One</option> \
                <option>Photos</option> \
              </select> =  \
              <select class="operation-select"> \
                <option>Select One</option> \
                <option value="count">Count</option> \
                <option value="value">Value</option> \
              </select> of  \
              <select class="field-select"> \
                <option>Select One</option> \
                <option value="1">Field One</option> \
              </select> \
              <a class="remove-goal-item"><i class="icon-minus-rounded"></i></a> \
            </div>';

    return s;
  }


	App.CampaignBuilder.Views = Views;
}(jQuery));
