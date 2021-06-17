(function($) {
	'use strict';

	var CampaignBuilder = {
    phaseCount: 0,
    // Initialization
    init: function() {
      CampaignBuilder.events();
      $.subscribe('campaign-tabs.show', function() {
        var builderData = $('#campaign-builder-data').data();
        // setup user auth with API
        $.ajaxSetup({
          headers: {
            "X-Auth-Token": builderData.authtoken,
            "X-User-Email": builderData.email,
            "X-Company-Id": builderData.company
          }
        });

        CampaignBuilder.baseAPI = '/api/v1/campaigns/' + builderData.campaign;

        // Fetch Phases for Campaign
        $.get(CampaignBuilder.baseAPI + '/phases.json', function(res) {
          console.log(res);
          CampaignBuilder.phaseCount = res.length;
          for(var i = 0; i < res.length; i++) {
            //Add to Phase to Campaign Builder
            $('#add-phase').before(CampaignBuilder.Views.newPhaseForm(res[i], true, res));
          }
          $('#campaign-build-zone').sortable({ 
            handle: '.phase-counter',
            axis: 'y',
            update: function(e, ui) {
              CampaignBuilder.calculatePhaseCounter();
            }
          });
          $('#modules-fields, #custom-activities').find('.activity').draggable({
            connectToSortable: '.phase-activity-list',
            revert: 'invalid',
            helper: 'clone',
            appendTo: 'body'
          });
          CampaignBuilder.initializePhaseSortable();
        });
      });
    },

    // Catch all event handlers
    events: function() {
      $('body')
      // Global
      .on('click', '#campaign-build-zone .block-info .nav-tabs a', CampaignBuilder.tabbing)

      // Phase related
      .on('click', '#add-phase', CampaignBuilder.addPhase)
      .on('click', '.btn-save-phase', CampaignBuilder.savePhaseHandler)
      .on('click', '.btn-cancel-phase', CampaignBuilder.cancelCreatePhase)
      .on('keyup', '.phase-name-input', CampaignBuilder.watchPhaseNameChange)
      .on('click', '.block-title-wrapper', CampaignBuilder.toggleEditPhaseForm)
      .on('focus', '.phase-name-input', CampaignBuilder.selectAllTextIfUntitled)
      .on('click', '.phase-delete', CampaignBuilder.deletePhase)
      .on('click', '.add-phase-condition', CampaignBuilder.addConditionalItemToPhase)
      .on('click', '.remove-phase-conditional-item', CampaignBuilder.removeConditionalItemFromPhase)
      .on('change', '.phases-select', CampaignBuilder.onPhasesSelectChange)

      // Activity related
      .on('keyup', '.activity-display-name-input', CampaignBuilder.watchActivityDisplayNameChange)
      .on('click', '.btn-save-activity', CampaignBuilder.saveActivityHandler)
      .on('click', '.activity-delete', CampaignBuilder.deleteActivity)

      // Activity Conditional Related
      .on('click', '.add-activity-condition', CampaignBuilder.addConditionalItemToActivity)
      .on('click', '.remove-activity-conditional-item', CampaignBuilder.removeConditionalItemFromActivity)

      // Activity Goals related
      .on('click', '.add-activity-goal', CampaignBuilder.addGoalItemToActivity)
      .on('click', '.remove-goal-item', CampaignBuilder.removeGoalItemFromActivity);
    },

    // Functionality
    addPhase: function(e) {
      CampaignBuilder.phaseCount++;
      $(this).before(CampaignBuilder.Views.newPhaseForm({ name: 'Untitled', order: CampaignBuilder.phaseCount }));
      CampaignBuilder.initializePhaseSortable();
    },
    tabbing: function(e) {
      var $this = $(this);
      $this.parents('.block-info').find('.tab-pane').removeClass('active');
      $this.parents('.block-info').find('.tab-pane' + $this.data('target')).addClass('active');
      $this.parent().siblings().removeClass('active');
      $this.parent().addClass('active');
    },
    savePhaseHandler: function(e) {
      var $block = $(this).parents('.builder-block.phase-block');
      CampaignBuilder.savePhase($block);
      CampaignBuilder.closeInfo($block);
    },
    cancelCreatePhase: function(e) {
      var $currentPhase = $(this).parents('.phase-block');
      if($currentPhase.data('id')) {
        CampaignBuilder.closeInfo($currentPhase);
      }
      else {
        $currentPhase.animate({ height: 0, opacity: 0 }, 'slow', function() { 
          $currentPhase.remove(); 
        });
      }
    },
    watchPhaseNameChange: function(e) {
      var $this = $(this);
      $this.parents('.builder-block.phase-block').find('.phase-title').text($this.val());
    },
    watchActivityDisplayNameChange: function(e) {
      var $this = $(this);
      $this.parents('.builder-block.activity-block').find('.block-title-wrapper').text($this.val());
    },
    toggleEditPhaseForm: function(e) {
      var $block = $(this).parents('.builder-block').first();
      if($block.hasClass('closed')) {
        CampaignBuilder.openInfo($block);
      }
      else {
        CampaignBuilder.closeInfo($block);
      }
    },
    selectAllTextIfUntitled: function(e) {
      if($(this).val() == 'Untitled') {
        $(this).select();
      }
    },
    deletePhase: function(e) {
      e.stopPropagation();
      var $block = $(this).parents('.builder-block.phase-block');
      if(confirm('Are you sure you want to delete this phase?')) {
        $.ajax({
          type: 'DELETE',
          url: CampaignBuilder.baseAPI + '/phases/' + $block.data('id') + '.json',
          success: function(res) {
            $block.fadeOut(400, function() {
              $block.remove();
              CampaignBuilder.calculatePhaseCounter();
            });
          }
        });
      }
    },
    addConditionalItemToPhase: function(e) {
      $(this).siblings('.phase-logic').show();
      $(this).siblings('.phase-conditions-list').append(CampaignBuilder.Views.PhaseConditionalItem({}, CampaignBuilder.getPhases()));
    }, 
    removeConditionalItemFromPhase: function(e) {
      var $this = $(this);
      var $list = $this.parents('.phase-conditions-list');
      $this.parent().hide();
      if($list.find('.phase-conditional-item').length == 0) {
        $list.siblings('.phase-logic').hide();
      }

      if($this.parent().data('id')) {
        $.ajax({
          type: 'DELETE',
          url: CampaignBuilder.baseAPI + '/phases/' + $this.parents('.builder-block.phase-block').data('id') + '/phase_conditions/' + $this.parent().data('id') + '.json',
          success: function(res) {
            $this.parent().hide();
          }
        });
      }
    },
    onPhasesSelectChange: function(e) {
      var $this = $(this);
      console.log($this.siblings('.condition-select option.date'), $this.siblings('.condition-select option:not(.date)'));
      if($this.val() == '-1' || $this.val() == '-2') {
        $this.siblings('.condition-select, .operator-select').find('option.date').removeClass('hide');
        $this.siblings('.condition-select, .operator-select').find('option:not(.date)').addClass('hide');
      }
      else {
        $this.siblings('.condition-select, .operator-select').find('option.date').addClass('hide');
        $this.siblings('.condition-select, .operator-select').find('option:not(.date)').removeClass('hide');
      }
    },


    // Activity event handlers
    saveActivityHandler: function(e) {
      var $activityBlock = $(this).parents('.builder-block.activity-block');
      CampaignBuilder.saveActivity($activityBlock);
      CampaignBuilder.closeInfo($activityBlock);
    },
    addConditionalItemToActivity: function(e) {
      var $this = $(this);
      $this.siblings('.activity-logic').show();
      $this.siblings('.activity-conditions-list').append(CampaignBuilder.Views.ActivityConditionalItem({}, $this.parents('.phase-block').data('model').phase_activities));
    }, 
    removeConditionalItemFromActivity: function(e) {
      var $this = $(this);
      var $list = $this.parents('.activity-conditions-list');
      $this.parent().hide();
      if($list.find('.activity-conditional-item').length == 0) {
        $list.siblings('.activity-logic').hide();
      }

      if($this.parent().data('id')) {
        $.ajax({
          type: 'DELETE',
          url: CampaignBuilder.baseAPI + '/phases/' + $this.parents('.builder-block.phase-block').data('id') + '/phase_activities/' + $this.parents('.activity-block').data('id') + '/phase_activity_conditions/' + $this.parent().data('id') + '.json',
          success: function(res) {
            $this.parent().hide();
          }
        });
      }
    },
    addGoalItemToActivity: function(e) {
      $(this).siblings('.activity-goals-list').append(CampaignBuilder.Views.ActivityGoalItem());
    },
    removeGoalItemFromActivity: function(e) {
      $(this).parent().remove();
    },
    deleteActivity: function(e) {
      e.stopPropagation();
      var $block = $(this).parents('.builder-block.activity-block');
      if(confirm('Are you sure you want to delete this activity?')) {
        $.ajax({
          type: 'DELETE',
          url: CampaignBuilder.baseAPI + '/phases/' + $block.parents('.builder-block.phase-block').data('id') + '/phase_activities/' + $block.data('id') + '.json',
          success: function(res) {
            $block.fadeOut(400, function() {
              $block.remove();
              CampaignBuilder.calculateActivitiesCounter($block.find('.phase-activity-list'));
            });
          }
        });
      }
    },

    // Helper Functions
    closeInfo: function($block) {
      $block.find('.block-info').first().slideUp(300, function() {
        $block.addClass('closed');
      });
    },
    openInfo: function($block) {
      $block.removeClass('closed').find('.block-info').first().slideDown(300);
    },
    calculatePhaseCounter: function() {
      $('#campaign-build-zone .builder-block.phase-block').each(function() {
        var $this = $(this);
        $this.find('.block-counter').first().text($this.index() + 1);
        // v1.0 TODO: optimize this to not be 1 api call per phase
        CampaignBuilder.savePhase($this);
      });
    },
    calculateActivitiesCounter: function($phaseActivityList) {
      $phaseActivityList.find('.activity-block').each(function() {
        var $this = $(this);
        $this.find('.block-counter').text($this.index() + 1);
        console.log('here cac');
        CampaignBuilder.saveActivity($this);
      });
    },
    initializePhaseSortable: function() {
      $('.phase-activity-list').sortable({
        tolerance: 'pointer',
        receive: function(e, ui) {
          console.log('receive');
          var match = false;
          $(this).find('.activity-block').each(function() {
            if($(this).data('activitytype') == ui.item.data('type') && $(this).data('activityid') == ui.item.data('id')) {
              match = true;
            }
          });
          if(!match) {
            $(this).data().uiSortable.currentItem.replaceWith(
              CampaignBuilder.Views.ModuleBuilderBlock({
                activity_id: ui.item.data('id'),
                activity_type: ui.item.data('type'),
                display_name: ui.item.data('displayname')
              })
            );
          }
          else {
            $(this).data().uiSortable.currentItem.remove();
            alert('You can\'t add the same Activity to the same Phase more than once!');
          }
        },
        update: function(e, ui) {
          CampaignBuilder.calculateActivitiesCounter($(this));
        }
      });
      $('.phase-activity-dropzone').droppable({
        accept: '.ui-draggable',
        drop: function(e, ui) {
          console.log('drop');
          $(this).siblings('.phase-activity-list').append(
            CampaignBuilder.Views.ModuleBuilderBlock({
              order: 1,
              activity_id: $(ui.draggable).data('id'),
              activity_type: $(ui.draggable).data('type'),
              display_name: $(ui.draggable).data('displayname')
            })
          );
          CampaignBuilder.calculateActivitiesCounter($(this).siblings('.phase-activity-list'));
        }
      });
    },
    getPhase: function($block) {
      var phase = { 
        phase: {
          name: $block.find('.phase-name-input').val(),
          description: $block.find('.phase-description-textarea').val(),
          requires_approval: $block.find('.phase-requires-approval-checkbox').is(':checked'),
          order: $block.index() + 1,
          conditional_action: $block.find('.action-select').val(),
          conditional_status: $block.find('.status-select').val(),
        },
        phase_conditions: []
      };

      $block.find('.phase-conditional-item').each(function() {
        var o = {};
        var $this = $(this);
        if($this.data('id')) {
          o.id = $this.data('id');
        }
        o.conditional_phase_id = $this.find('.phases-select').val();
        o.condition = $this.find('.condition-select').val();
        o.operator = $this.find('.operator-select').val();
        phase.phase_conditions.push(o);
      });
      return phase;
    },
    getPhaseActivity: function($block) {
      var phase_activity = {
        phase_activity: {
          display_name: $block.find('.activity-display-name-input').val(),
          due_date: $block.find('.activity-due-date-datepicker').val(),
          required: $block.find('.activity-required-checkbox').is(':checked'),
          activity_type: $block.data('activitytype'),
          activity_id: $block.data('activityid'),
          order: $block.index() + 1,
          conditional_action: $block.find('.action-select').val(),
          conditional_status: $block.find('.status-select').val()
        },
        phase_activity_conditions: []
      };

      $block.find('.activity-conditional-item').each(function() {
        var o = {};
        var $this = $(this);
        if($this.data('id')) {
          o.id = $this.data('id');
        }
        o.conditional_phase_activity_id = $this.find('.activities-select').val();
        o.condition = $this.find('.condition-select').val();
        o.operator = $this.find('.operator-select').val();
        phase_activity.phase_activity_conditions.push(o);
      });

      return phase_activity;
    },
    savePhase: function($block) {
      $.ajax({
        type: $block.data('id') ? 'PUT' : 'POST',
        url: CampaignBuilder.baseAPI + ($block.data('id') ? '/phases/' + $block.data('id') + '.json' : '/phases.json'),
        data: CampaignBuilder.getPhase($block),
        success: function(res) {
          $block.data('id', res.id);
          $block.find('.phase-activities').show();
        }
      });
    },
    saveActivity: function($block) {
      var phase_id = $block.parents('.builder-block.phase-block').data('id');
      if(phase_id) {
        var api_url = CampaignBuilder.baseAPI + '/phases/' + phase_id + '/phase_activities.json';
        if($block.data('id')) {
          api_url = api_url.replace('.json', '/' + $block.data('id') + '.json');
        }
        $.ajax({
          type: $block.data('id') ? 'PUT' : 'POST',
          url: api_url,
          data: CampaignBuilder.getPhaseActivity($block),
          success: function(res) {
            $block.data('id', res.id);
          }
        });
      }
    },
    getPhases: function() {
      var arr = [];
      $('.phase-block').each(function() {
        arr.push($(this).data('model'));
      });
      return arr;
    }
  };

	// Run Initialization
	$(function(){
		CampaignBuilder.init();
	});

  App.CampaignBuilder = CampaignBuilder; //Exposing it globally
}(jQuery));
