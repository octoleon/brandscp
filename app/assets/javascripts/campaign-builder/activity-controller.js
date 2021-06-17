(function($) {
	'use strict';

	var CampaignBuilder = {

		test: function() { console.log('derp'); }
	};

	$.extend(App.CampaignBuilder, CampaignBuilder); //Exposing it globally
}(jQuery));