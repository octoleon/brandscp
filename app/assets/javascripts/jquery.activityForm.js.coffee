$.widget 'app.activityForm', {
	options: {
	},
	_create: () ->
		@element.off('change.activityCampaign').on "change.activityCampaign", "#activity_campaign_id", (e) =>
			brands  = @element.find(".form-field-brand")
			marques = @element.find("select.form-field-marque")
			target = @element.find('#activity_campaign_id')
			if selectedOption = target.val()
				$.get "/campaigns/#{selectedOption}/brands.json", (list) ->
					brands.empty()
					marques.empty()
					marques.trigger('liszt:updated')
					brands.append $("<option>",
						value: ""
						text: ""
						selected: true
					)
					for item in list
						brands.append $("<option>",
							value: item.id
							text: item.name
						)
					brands.trigger "liszt:updated"
					return
			else
				brands.empty()
				marques.empty()
				marques.trigger('liszt:updated')
				brands.trigger "liszt:updated"

			return

		@element.off('change.inviteCampaign').on 'change.inviteCampaign', '#venue_invite_campaign', (e) ->
			$.getJSON '/campaigns/'+$(@).val()+'/event_dates.json', (results) ->
				events = $('#invite_event_id');
				events.html('<option></option>')
				for result in results
					$('#invite_event_id').append('<option value="' + result[1] + '">' + result[0] + '</option>')
				events.trigger('liszt:updated')

		@element.off('change.activityBrand').on "change.activityBrand", ".form-field-brand", ->
			marques = $("select.form-field-marque")
			if selectedOption = @value
				$.get "/brands/#{selectedOption}/marques.json", (options) ->
					marques.empty().select2 "destroy"
					for i of options
						marques.append $("<option>",
							value: options[i].id
							text: options[i].name
						)
					marques.trigger('liszt:updated')
					return
			else
				marques.empty()
				marques.trigger('liszt:updated')
			return

		@element.on "keyup.activity", "input.calculation", ->
			sum = 0
			group = $(this).data("group")
			$.each $("input[data-group=\"#{group}\"][name!=\"total\"]"), (e) ->
				sum += parseFloat(@value) or 0
				return

			$("input[data-group=\"#{group}\"][name=\"total\"]").val sum
			return

		# Cancel any upload in progress if the modal is closed
		@element.parents('.modal').on 'hide', (e) =>
			@element.find('.attached_asset_upload_form').each (index, form) ->
				$(form).data("jqXHR").abort() if $(form).data("jqXHR")

}



