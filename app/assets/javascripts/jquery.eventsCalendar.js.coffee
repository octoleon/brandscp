
# these are the days of the week for each month, in order
cal_days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
cal_months_labels = ['January', 'February', 'March', 'April',
                     'May', 'June', 'July', 'August', 'September',
                     'October', 'November', 'December']
cal_days_labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

$.widget 'nmk.eventsCalendar', {
	options: {
		day: null,
		month: null,
		year: null,
		eventsUrl: null,
		renderMonthDay: null,
		showMonthControls: true,
		mode: 'month',
		onEventsLoad: false,
		onMonthChange: false,
		onGroupChange: false,
		weeks: 2,
		groupBy: null
	},

	_create: () ->
		@element.addClass('eventsCalendar')

		if @options.groupBy
			@groupBy = @options.groupBy
		else
			@groupBy = 'brand'

			if (typeof(Storage) isnt "undefined") && (typeof(localStorage) isnt 'undefined')  && localStorage.getItem("events_calendar_grouping")
				#@groupBy = localStorage.getItem("events_calendar_grouping")
				@groupBy = 'brand'


		cal_current_date = new Date()
		@day   = if (isNaN(@options.day) || @options.day == null) then cal_current_date.getDate() else @options.day
		@month = if (isNaN(@options.month) || @options.month == null) then cal_current_date.getMonth() else @options.month
		@year  = if (isNaN(@options.year) || @options.year == null) then cal_current_date.getFullYear() else @options.year

		if @options.mode == 'month'
			@_addControls()
		@calendar = $('<div>').appendTo @element
		@_drawCalendar()

		$(document).delegate '.calendar-view-more', 'click.eventsCalendar', (e) =>
			e.preventDefault()
			cell = $(e.target).closest('td')
			cell.addClass 'expanded'

		$(document).delegate '.close', 'click.eventsCalendar', (e) =>
			e.preventDefault()
			cell = $(e.target).closest('td')
			cell.removeClass 'expanded'

	_addControls: () ->
		title = 'Brand'
		title = 'Campaign' if @groupBy == 'campaign'
		title = 'User' if @groupBy == 'user'
		title = 'Event' if @groupBy == 'event'
		@element.append "<div class=\"calendar-controls\">
			<div class=\"calendar-month-name\"></div>
			<div class=\"calendar-months-arrows\">
				<a class=\"icon-angle-left prev-month-btn\" href=\"#\"></a>" +
				"<a class=\"icon-angle-right next-month-btn\" href=\"#\"></a>
			</div>
			<div class=\"calendar-grouping dropdown\">
				Group by: <a class=\"dropdown-toggle\" data-toggle=\"dropdown\" href=\"#\"><span>#{title}</span> <i class=\"icon-arrow-down\"></i></a>
				<ul class=\"dropdown-menu pull-right\">
					<li#{if @groupBy == 'brand' then ' class=\"active\"' else ''}><a href=\"#\" data-value=\"brand\"><i class=\"icon item-icon icon-star\"></i> Brand <i class=\"icon icon-checked pull-right\"></i></a></li>
					<li#{if @groupBy == 'campaign' then ' class=\"active\"' else ''}><a href=\"#\" data-value=\"campaign\"><i class=\"icon item-icon icon-campaign\"></i> Campaign <i class=\"icon icon-checked pull-right\"></i></a></li>
					<li#{if @groupBy == 'user' then ' class=\"active\"' else ''}><a href=\"#\" data-value=\"user\"><i class=\"icon item-icon icon-user\"></i> User <i class=\"icon icon-checked pull-right\"></i></a></li>
					<li#{if @groupBy == 'event' then ' class=\"active\"' else ''}><a href=\"#\" data-value=\"event\"><i class=\"icon item-icon icon-tasks\"></i> Event <i class=\"icon icon-checked pull-right\"></i></a></li>
				</ul>
			</div>
		</div>"

		@element.on 'click',  '.calendar-grouping .dropdown-menu a', (e) =>
			e.preventDefault()
			$a = $(e.currentTarget)
			@groupBy = $a.data('value')
			localStorage.setItem('events_calendar_grouping', @groupBy) if typeof(Storage) isnt "undefined"
			@element.find('.calendar-grouping .dropdown-toggle span').text($a.text())
			@element.find('.calendar-grouping .dropdown-menu li').removeClass('active')
			$a.parent().addClass('active')
			@_drawCalendar()
			@options.onGroupChange() if @options.onGroupChange
			true

		@element.on 'click', '.prev-month-btn', (e) =>
			e.preventDefault()
			@_moveMonth(-1)

		@element.find('.next-month-btn').on 'click', (e) =>
			e.preventDefault()
			@_moveMonth(1)

	_drawCalendar: () ->
		if @options.mode is 'weeks'
			@_drawWeeksCalendar()
		else
			@_drawMonthCalendar()

	_drawMonthCalendar: () ->
		# get first day of the calendar
		@firstDay = @lastDay = currentDay = new Date(@year, @month, 1)
		startingDay = @firstDay.getDay()
		if startingDay != 0
			diff = if startingDay == 0 then 0 else startingDay * -1 + 1
			currentDay = new Date(@firstDay.setDate(diff))

		@_updateMonthName()

		# find number of days in month
		monthLength = cal_days_in_month[@month]

		# compensate for leap year
		if (@month == 1) # February only!
			if((@year % 4 == 0 && @year % 100 != 0) || @year % 400 == 0)
				monthLength = 29;

		html = '<table class="calendar-table">'
		html += '<thead>'
		html += '<tr class="calendar-header">'
		for i in [0..6]
			html += "<th class=\"calendar-header-day\">#{cal_days_labels[i]}</th>"
		html += '</tr></thead><tbody><tr>'

		# fill in the days
		# this loop is for is weeks (rows)
		for i in [0..8]
			# this loop is for weekdays (cells)
			for j in [0..6]
				dayTitle = "#{cal_days_labels[currentDay.getDay()]} #{cal_months_labels[currentDay.getMonth()].substring(0,3)} #{currentDay.getDate()}"
				html += "<td class=\"calendar-day\" id=\"#{currentDay.getFullYear()}_#{currentDay.getMonth()+1}_#{currentDay.getDate()}\"><div class=\"calendar-cell-wrapper\">"
				html += "<div class=\"calendar-day-events-container\"><a href=\"#\" class=\"close\"></a><span class=\"daytitle\">#{dayTitle}</span></div>"
				html += "<div class=\"calendar-view-more\"></div>"
				html += "<div class=\"calendar-month-day\">"
				if @options.renderMonthDay
					html += @options.renderMonthDay(currentDay)
				else
					html += currentDay.getDate()
				html += "</div>"
				currentDay = new Date(currentDay.getFullYear(), currentDay.getMonth(), currentDay.getDate()+1)
				@lastDay = currentDay
				html += '</div></td>'

			if currentDay.getMonth() != @month
				break
			else
				html += '</tr><tr>'

		html += '</tr></tbody></table>'

		@calendar.html html

		if @options.eventsUrl
			@loadEvents()

		@

	_drawWeeksCalendar: () ->
		# get first day of the calendar
		@firstDay = @lastDay = currentDay = new Date(@year, @month, @day)
		startingDay = @firstDay.getDay()

		# Creates an array with all the days (twice) of the week starting Monday ending Sunday
		cal_days = cal_days_labels.concat(cal_days_labels)

		html = '<table class="calendar-table">'
		html += '<thead>'
		html += '<tr class="calendar-header">'
		for i in [0..6]
			html += "<th class=\"calendar-header-day\">#{cal_days[i+@firstDay.getDay()]}</th>"
		html += '</tr></thead><tbody>'

		# fill in the days
		# this loop is for is weeks (rows)
		for i in [0..@options.weeks-1]
			html += '<tr>'
			# this loop is for weekdays (cells)
			for j in [0..6]
				dayTitle = "#{cal_days[currentDay.getDay()]} #{cal_months_labels[currentDay.getMonth()].substring(0,3)} #{currentDay.getDate()}"
				html += "<td class=\"calendar-day\" id=\"#{currentDay.getFullYear()}_#{currentDay.getMonth()+1}_#{currentDay.getDate()}\"><div class=\"calendar-cell-wrapper\">"
				html += "<div class=\"calendar-day-events-container\"><a href=\"#\" class=\"close\"></a><span class=\"daytitle\">#{dayTitle}</span></div>"
				html += "<div class=\"calendar-view-more\"></div>"
				html += "<div class=\"calendar-month-day\">"
				if @options.renderMonthDay
					html += @options.renderMonthDay(currentDay)
				else
					html += currentDay.getDate()
				html += "</div>"
				currentDay = new Date(currentDay.getFullYear(), currentDay.getMonth(), currentDay.getDate()+1)
				html += '</div></td>'

			if currentDay.getMonth() != @month
				break
			else
				@lastDay = currentDay
				html += '</tr>'

		html += '</tbody></table>'

		@calendar.html html

		if @options.eventsUrl
			@loadEvents()

		@

	_updateMonthName: () ->
		# do the header
		monthName = cal_months_labels[@month]

		@element.find('.calendar-month-name').html "#{monthName}&nbsp;#{@year}"

	loadEvents2: () ->
		alert 'si'

	loadEvents: () ->
		@calendar.find('.calendar-event').remove()
		if typeof @options.eventsUrl is 'function'
			url = @options.eventsUrl()
		else
			url = @options.eventsUrl
		$.get url, {start: @firstDay.getTime()/1000, end: @lastDay.getTime()/1000, group: @groupBy}, (response) =>
			@calendar.find('.calendar-event').remove()
			if response && response.length > 0
				for eventElement in response
					parts = eventElement.start.split('-')
					d = new Date(parts[0], parseInt(parts[1], 10)-1, parts[2])
					cell = @calendar.find("##{d.getUTCFullYear()}_#{d.getUTCMonth()+1}_#{d.getUTCDate()}")
					if cell.length > 0
						cell.find('.calendar-day-events-container').append @_renderEvent(eventElement)

			for cell in @calendar.find('td.calendar-day')
				elements = $('.calendar-event', cell)
				diff = elements.length - 6
				if diff > 0
					$('.calendar-view-more', cell).html "<a href=\"#\">+#{diff} More</a>"

			@options.onEventsLoad() if @options.onEventsLoad

			true
		@

	getMonth: () ->
		@month || @options.month

	getYear: () ->
		@year || @options.year

	getGroupBy: () ->
		@groupBy || @options.groupBy

	_renderEvent: (eventElement) ->
		title = if eventElement.url? then $('<a>').attr('href', eventElement.url).text(eventElement.title) else eventElement.title
		$('<div>').addClass('calendar-event').append([
			$('<span class="calendar-event-bullet">&#8226;</span>').css('color': eventElement.color),
			$('<span class="calendar-event-name"></span>').append(title).tooltip({placement: 'bottom', html: true, title: eventElement.description, container: 'body'}),
		])

	_moveMonth: (step) ->
		@year = if @month is 0 and step < 0 then @year - 1 else @year
		@year = if @month is 11 and step > 0 then @year + 1 else @year
		d = new Date(@year, @month+step, 1)
		@month = d.getMonth()
		@_drawCalendar()
		@options.onMonthChange(@month, @year) if @options.onMonthChange
		@
}
