(function($) {
	'use strict';

	var EventDetails = {
    // Initialization
    init: function() {
      EventDetails.events();
    },

    // Catch all event handlers
    events: function() {
      $('body');
    },
  };

	// Run Initialization
	$(function(){
    if($('.event-details').length) {
		  EventDetails.init();
    }
	});

  App.EventDetails = EventDetails; //Exposing it globally
}(jQuery));
