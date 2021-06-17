$.widget 'app.placesAutocomplete', {
	options: {
		select: false
	},

	_create: () ->
		@value = @element.val()
		@url = '/places/search.json'
		@location = ''
		@element.places_autocomplete
			source: ( request, response ) =>
				@xhr.abort() if @xhr
				data =
					term: request.term
					location: @location
					'check-valid': @element.data('check-valid')
				data = $.extend(data, @element.data('search-params')) if @element.data('search-params')
				@xhr = $.ajax
					url: @url
					data: data
					dataType: 'json'
					success: ( data ) -> response data
					error: () -> response []
			appendTo: @element.parent()
			select: ( event, ui ) =>
				if ui.item.valid is false
					event.preventDefault()
					return false

				$(@element.data('hidden')).val ui.item.id
				$(@element.data('hidden')).change();
				@value = ui.item.label
				if typeof @options.select is 'function'
					@options.select()

		@element.blur (e) =>
			if @element.val() == ''
				$(@element.data('hidden')).val ''
			else
				@element.val @value

		@getLocation()

	getLocation: () ->
		if navigator.geolocation
			navigator.geolocation.getCurrentPosition (p) =>
				@location = "#{p.coords.latitude},#{p.coords.longitude}"
}


$.widget "custom.places_autocomplete", $.ui.autocomplete, {
	_renderMenu: ( ul, items ) ->
		that = this
		$.each items, (index, item) ->
			that._renderItemData ul, item
		$( "<li>" )
			.addClass('ui-menu-item')
			.appendTo(ul.addClass('places_autocomplete'));

	_renderItem: ( ul, item ) ->
		newText = String(item.value).replace(
			new RegExp(this.term, "gi"),
			"<strong>$&</strong>");

		$("<li></li>")
			.addClass('ui-menu-item ' + (if item.valid then 'valid-place' else 'invalid-place'))
			.data("item.autocomplete", item)
			.append("<i class='icon-venue'></i>")
			.append("<a>" + newText + "</a>")
			.appendTo(ul)
}
