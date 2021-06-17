photoGalleryCounter = 0
$.widget 'nmk.photoGallery', {
	options: {
		showSidebar: true,
		applyTo: null
	},

	_create: () ->
		@element.addClass('photoGallery')
		@_createGalleryModal()

		$(document).on 'attached-asset:activated', (e, id) =>
			if @image && @image.data('image-id') is id
				@showImageInfo(@image)
				true

		$(document).on 'attached-asset:deactivated', (e, id) =>
			if @image && @image.data('image-id') is id
				@photoToolbar.html ''
				$('.carousel', @gallery).carousel('next')
				@gallery.find('[data-photo-id='+id+']').remove()
				true

		@element.on 'click', 'a[data-toggle="gallery"]', (e) =>
			e.preventDefault()
			image = $(e.currentTarget).find('img')[0]
			@buildCarousels image
			@gallery.modal 'show'
			@image = $(image)
			@showImageInfo @image
			false
		@

	fillPhotoData: (info) ->
		if @options.showSidebar
			@setTitle info.title, info.urls.campaign
			date = if @image.data('info').source.type == 'activity_venue' then null else info.date
			@setDate date, info.urls.event
			@setAddress info.address, info.urls.venue
			@setSource info.source.title, info.source.url
			@setRating info.rating, info.id
			@setTagList info.tags
		@_createPhotoToolbar()

	showImageInfo: (image) ->
		if image.data('info')
			@fillPhotoData image.data('info')
		else
			$.ajax "/photos/#{@image.data('image-id')}", {
				method: 'GET',
				dataType: 'json',
				async: false,
				success: (info) =>
					if info.id is _this.image.data('image-id')
						image.data('info', info)
						@fillPhotoData(info)
			}

	setTagList: (tags) ->
		if 'view_tag' in @image.data('info').permissions
			if 'add_tag' in @image.data('info').permissions
				@createTagsControl tags
			else
				@tags_list.hide()
			@setTags()
			@gallery.find('.photo-tags').show()
		else
			@gallery.find('.photo-tags').hide()

	updateTags: (tags) ->
		@tags_list.select2 $.extend(@_select2Options(), {tags: tags})
		@tags_list.select2("container").find(".select2-input").attr("placeholder", "Add tags")
		if @image
			@tags_list.select2 'data', @image.data('info').tags

	createTagsControl: (tags, force=false) ->
		if @tags_list.initialized? and !force
			@tags_list.select2 'data', tags
		else
			$.get '/tags.json', (alltags) =>
				@tags_list.initialized = true
				#@tags_list.select2 $.extend(@_select2Options(), {tags: alltags, data: tags})
				@tags_list.select2 $.extend(@_select2Options(), {tags: alltags})
				@tags_list.select2("container").find(".select2-input").attr("placeholder", "Add tags")
				@tags_list.select2('data', tags);

	_select2Options: () ->
		placeholder: 'Add tags'
		dropdownCssClass: 'select2-dropdown'
		createSearchChoice: (term, data) =>
			if 'create_tag' in @image.data('info').permissions
				{id: term, text: term}
			else
				return null


	setTitle: (title, url) ->
		if url
			@title.find('span').html($('<a>').attr('href', url).html(title))
		else
			@title.find('span').html(title)

	setRating: (rating, asset_id) ->
		if 'view_rate' in @image.data('info').permissions
			can_rate = (if 'rate' in @image.data('info').permissions then true else false)
			$stars = new Array(5)
			$i = 0
			while $i < rating
				$stars[$i] = @_createStar($i+1,true, asset_id, can_rate)
				$i++
			while $i < 5
				$stars[$i] = @_createStar($i+1,false, asset_id, can_rate)
				$i++

			@rating.html ''
			@rating.append $stars
			@ratingContainer.append(@rating)
			@rating.show()
		else
			@rating.hide()

	setSource: (title, url) ->
		if url
			@source.find('span').html($('<a>').attr('href', url).html(title))
		else
			@source.find('span').html title

	setDate: (date, url) ->
		if date
			@date.show().find('span').html($('<a>').attr('href', url).html(date))
		else
			@date.hide().find('span').html('')

	setAddress: (address, url) ->
		if url
			if typeof @options.applyTo != 'undefined' && @options.applyTo != 'venues'
				@address.find('span').html($('<a>').attr('href', url).html(address))
			else
				@address.find('span').html address
		else
			@address.find('span').html address

	setTag: (tag) ->
		if tag.added
			@addTag(tag.added)

	addTag: (tag) ->
		id = @image.data('image-id')
		setTagCloseButton = @setTagCloseButton(tag, id)
		$.ajax "/attached_assets/"+@image.data('image-id')+'/tags/'+tag['id']+'/activate', {
			method: 'GET',
			dataType: 'script',
			success: (e) =>
				@setTags()
				@tags_list.select2('data', @image.data('info').tags)
			}

	setTags: () ->
		@tags.html ''
		if @image
			@tags.append($('<div class="tag" id="tag_'+tag['id']+'">').text(tag['text']).prepend(@setTagCloseButton(tag))) for tag in @image.data('info').tags
		@tags.show()

	setTagCloseButton: (tag) ->
		if 'deactivate_tag' in @image.data('info').permissions
			button = $('<a href="#" class="icon-close remove-tag" title="Remove Tag">').on 'click', (e) =>
				@removeTag(tag)
				false

	removeTag: (tag) ->
		$.ajax "/attached_assets/"+@image.data('image-id')+'/tags/'+tag['id']+'/remove', {
			method: 'GET',
			dataType: 'script',
			success: (e) =>
				$('#tag_'+tag['id']).remove()
				@tags_list.select2('data', @image.data('info').tags)
				$('#tag_input').click()
		}

	buildCarousels: (currentImage) ->
		i = 0
		activeClass = false

		if @options.showSidebar
			miniCarousel = @miniCarousel.find('.carousel-inner')
			miniCarousel.html('')

		carousel = @carousel.find('.carousel-inner')
		carousel.html('')

		for link in @element.find('a[data-toggle=gallery]')
			image = $(link).find('img')[0]
			if currentImage == image
				activeClass = 'active'
			else
				activeClass = ''

			if miniCarousel
				item = $('<div class="item">').addClass(activeClass)
					.on 'click', (e) =>
						@_rewindVideos()
						true
				miniCarousel.append(item.append($('<img>').attr('src', image.src).data('image', image).attr('data-photo-id', $(image).data('imageId')).data('index', i)))

			carousel.append $('<div class="item">').
				attr('data-photo-id', $(image).data('imageId')).
				append($('<div class="row">').append($('<img class="img-carousel">').attr('id', 'img_'+$(image).data('imageId')).attr('src', '').data('src', link.href))).
				data('image', image).
				data('index', i).
				addClass(activeClass)
			i+=1

		if @options.showSidebar
			@miniCarouselItems = i

			@_setMiniCorouselClases(@miniCarousel.find('.item.active')[0])

			@miniCarousel.off('click.thumb').on 'click.thumb', 'img', (e) =>
				index = $(e.target).data('index')
				@carousel.carousel index

			@miniCarousel.appendTo @gallery.find('.mini-slider')

			@miniCarousel.carousel 'pause'

	_createStar: ($i, $is_full, $asset_id, can_rate) ->
		$klass = ""
		if $is_full
			$klass = "icon-star full"
		else
			$klass = "icon-wired-star"
		star = $('<span class="'+$klass+'" value="'+$i+'"/>')
		if can_rate
			star.click (e) =>
				@image.data('info').rating = $i
				@rating.find('span').slice(0,$i).removeClass('temp-full')
				$.ajax "/attached_assets/"+$asset_id+'/rate', {
					method: 'PUT',
					data: { rating: $i},
					dataType: 'json'
				}
			.mouseover (e) =>
				@rating.find('span').removeClass('icon-star full temp-full').addClass('icon-wired-star').css('cursor','pointer')
				@rating.find('span').slice(0,$i).removeClass('icon-wired-star').addClass('icon-star temp-full')

		star

	_createGalleryModal: () ->
		@title = $('<div class="campaign-data"><i class="icon-campaign-flag"></i><span></span></div>')
		@date = $('<div class="calendar-data"><i class="icon-calendar"></i><span></span></div>')
		@address = $('<div class="place-data"><i class="icon-wired-venue"></i><span></span></div>')
		@source = $('<div class="source-data"><i class="icon-source"></i><span></span></div>')
		@ratingContainer = $('<div class="rating-container"><span class="rating-header-text">Rate this photo:</span></div>')
		@rating = $('<div class="rating">')
			.mouseleave (e) =>
				@rating.find('span').removeClass('icon-star full temp-full').addClass('icon-wired-star')
				@rating.find('span').slice(0,@image.data('info').rating).addClass('icon-star').removeClass('icon-wired-star')

		@tags_list = $('<input id="tag_input" multiple="true" class="select2-field typeahead">')
			.on "change", (e) =>
				@setTag(e)

		if @gallery
			@gallery.remove();
			@gallery.off('shown')

		if @carousel
			@carousel.off('slid').remove()

		if @options.showSidebar
			@gallery = $('<div class="gallery-modal modal hide fade">').append(
				$('<div class="gallery-modal-inner">').append(
					$('<div class="panel">').
						append('<a href="#" class="icon-close close-gallery" data-dismiss="modal" aria-hidden="true" title="Close"></a>').
						append(
							$('<div class="description">').append( @title ).append( @date ).append( @address ).append( @source ),
							$('<div class="mini-slider">').append( @miniCarousel = @_createCarousel('small') ),
							@ratingContainer,
							$('<div class="photo-tags">').append(
								$('<div class="icon-tag">'),
								$('<div class="tags">').append( @tags = $('<div id="list" class="list">') , @tags_list)
							)
						),
					$('<div class="slider">').append( $('<div class="slider-inner">').append( @carousel = @_createCarousel() ) ).append( @photoToolbar = $('<div class="photo-toolbar">') )
				).append($('<div class="clearfix">'))
			)
		else
			@gallery = $('<div class="gallery-modal modal hide fade">').append(
				$('<div class="gallery-modal-inner">').append(
					$('<div class="slider">').
						append($('<div class="photo-toolbar-header">').
							append('<a class="icon-close" data-dismiss="modal" aria-hidden="true" title="Close"></a>')).
						append( $('<div class="slider-inner unique">').
							append( @carousel = @_createCarousel() ) ).
						append( @photoToolbar = $('<div class="photo-toolbar">') )
				).append($('<div class="clearfix">'))
			)

		@tags_list.initialized = null


		@gallery.insertAfter @element

		@gallery.on 'shown', () =>
			@_showImage()
			$(window).on 'resize.gallery', =>
				@_updateSizes()
			$(document).on 'keyup.gallery', (e) =>
				if e.which is 39
					$('.carousel.small').carousel('next');
					e.preventDefault();
					false
				else if e.which is 37
					$('.carousel.small').carousel('prev');
					e.preventDefault();
					false
				else if e.which is 27
					@gallery.modal 'hide'
					e.preventDefault();
					false
			.on 'hidden', () =>
				$(window).off 'resize.gallery'
				$(document).off 'keyup.gallery'


		# Just some shortcuts
		@slider = @gallery.find('.slider')
		@sliderInner = @gallery.find('.slider-inner')
		@panel = @gallery.find('.panel')

		if @options.showSidebar
			@miniCarousel.carousel interval: false
			@miniCarousel.on 'slide', (e) =>
				@_setMiniCorouselClases(e.relatedTarget)
		@carousel.carousel({interval: false})

		@carousel.on 'slid', (e) =>
			item = $('.item.active', e.target)
			@image = $(item.data('image'))
			@showImageInfo(@image)

			@_showImage()
			@miniCarousel.carousel parseInt(item.data('index'))

		@gallery

	_setMiniCorouselClases: (activeItem) ->
		prevItem = $(activeItem).prev('.item')
		nextItem = $(activeItem).next('.item')
		@miniCarousel.find('.item').removeClass('next-item').removeClass('prev-item')
		prevItem.addClass('prev-item')
		nextItem.addClass('next-item')
		if prevItem.length && @miniCarouselItems > 3 then @miniCarousel.find('.carousel-control.left').show() else @miniCarousel.find('.carousel-control.left').hide()
		if nextItem.length && @miniCarouselItems > 3 then @miniCarousel.find('.carousel-control.right').show() else @miniCarousel.find('.carousel-control.right').hide()
		if $(activeItem).is(':first-child') then nextItem.next('.item').addClass('next-item')
		if $(activeItem).is(':last-child') && (@miniCarouselItems % 3 is 0) then prevItem.prev('.item').addClass('prev-item')
		$(activeItem).find('img').trigger('click')
		true

	_showImage: () ->
		item = $('.item.active', @slider)
		image = item.find('img.img-carousel')
		if typeof @image != 'undefined' && @image.data('info').type == 'video' && image.css('display') != 'none'
			image.css('display', 'none')
			videoTag = $('<video id="video-'+@image.data('info').id+'"><source src="'+@image.data('info').urls.video+'" type="video/mp4"/><em>Your browser does not support this video file.</em></video>')
							.on 'click', (e) =>
								target = $(e.target)[0]
								playIcon = $('#'+target.id+'-icon')
								if target.paused
									playIcon.hide()
									target.play()
								else
									playIcon.show()
									target.pause()
							.on 'ended', (e) =>
								target = $(e.target)[0]
								target.currentTime = 0
								$('#'+target.id+'-icon').show()
			image.parent().append(
				$('<div class="video-container">').append(videoTag)
			)
			image.parent().append(
				$('<div id="video-'+@image.data('info').id+'-icon" class="enlarged-circle">').append($('<span class="icon-video-play"></span>'))
					.on 'click', (e) =>
						videoTag.trigger('click')
						true
			)

		if typeof image.attr('src') == 'undefined' || image.attr('src') == ''
			image.css({opacity: 0}).attr('src', image.data('src')).on 'load', (e) =>
				$(e.target).css({opacity: 1})
				@_updateSizes()
		else
			@_updateSizes()

		@carousel.find('.carousel-control img').attr('src', image.data('src'))

		# Preload the next image
		nextItem = item.next('.item')
		if nextItem.length
			img = new Image()
			img.src = nextItem.find('img').data('src')

	_createPhotoToolbar: () ->
		@photoToolbar.html ''
		@photoToolbar.append(
			urls = @image.data('info').urls
			(if 'deactivate_photo' in @image.data('info').permissions && @options.showSidebar
				if @image.data('info').status == true
					$('<a class="icon-remove-circle photo-deactivate-link" title="Deactivate" data-remote="true" data-confirm="Are you sure you want to deactivate this photo?"></a>').attr('href', urls.deactivate)
				else
					$('<a class="icon-rounded-ok photo-deactivate-link" title="Activate" data-remote="true"></a>').attr('href', urls.activate)
			else
				null
			),
			(if 'download' in @image.data('info').permissions
				$('<a class="icon-download" title="Download"></a>').attr('href', urls.download)
			else
				null
			)
		)

	_createCarousel: (carouselClass='') ->
		id = "gallery-#{@_generateUid()}"
		$carousel = $('<div id="'+id+'" class="gallery-carousel carousel">').addClass(carouselClass).append($('<div class="carousel-inner">'))
		if @options.showSidebar
			$carousel.append(
				($('<a class="carousel-control left" data-slide="prev" href="#'+id+'"><img /><span><i class="icon-slimmed-arrow-left-rounded"></i></span></a>')
					.on 'click', (e) =>
						@_rewindVideos()
						true
				),
				($('<a class="carousel-control right" data-slide="next" href="#'+id+'"><img /><span><i class="icon-slimmed-arrow-right-rounded"></i></span></a>')
					.on 'click', (e) =>
						@_rewindVideos()
						true
				)
			)

		$carousel

	_rewindVideos: () ->
		$('video').each (i) ->
			target = $(this)[0]
			$(this)[0].pause()
			target.currentTime = 0
			$('#'+target.id+'-icon').show()

	_findBaseName: (url) ->
		fileName = url.substring(url.lastIndexOf('/') + 1)
		questionMark = fileName.lastIndexOf('?')
		if questionMark == -1 then fileName else fileName.substring(0, questionMark)

	_updateSizes: () ->
		# If the current image's height is greater than the carousel's height then
		# changes the carousel's height to that height but only if it's not higher than
		# the windows height, in that case the image is resized to that
		image = @carousel.find('.active img')

		# Get image natural size
		imageNatural = @getNatural(image[0])

		# Set the slider/images widths based on the  available space and image dimensions
		minSliderWidth = parseInt(@slider.css('min-width')) or 400
		minSliderHeight = parseInt(@slider.css('min-height')) or 470
		maxSliderHeight = windowHeight-20
		windowWidth = $(window).width()
		windowHeight = $(window).height()
		maxSliderWidth = windowWidth-@panel.outerWidth()-20
		maxSliderHeight = windowHeight-20
		sliderWidth = @slider.width()
		sliderHeight = @slider.height()

		imageWidth = Math.min(maxSliderWidth, imageNatural.width)
		imageHeight = Math.min(maxSliderHeight, imageNatural.height)

		if imageWidth < minSliderWidth && imageNatural.width > minSliderWidth
			imageWidth = minSliderWidth

		if imageHeight < minSliderHeight && imageNatural.height > minSliderHeight
			imageHeight = minSliderHeight

		if imageWidth < imageNatural.width
			proportion = imageWidth/imageNatural.width
			newHeight = parseInt(imageNatural.height*proportion)
			imageHeight = newHeight

		if imageHeight < imageNatural.height
			proportion = imageHeight/imageNatural.height
			imageWidth = parseInt(imageNatural.width*proportion)

		sliderHeight = Math.max(minSliderHeight, Math.min(maxSliderHeight, Math.max(sliderHeight, imageHeight)))

		if @options.showSidebar
			sliderWidth = Math.max(minSliderWidth, Math.min(maxSliderWidth, Math.max(sliderWidth, imageWidth)))
			modalWidth = Math.min(@panel.outerWidth()+sliderWidth, windowWidth-10)
		else
			sliderWidth = Math.max(minSliderWidth, Math.min(maxSliderWidth, imageWidth))
			modalWidth = Math.min(sliderWidth, windowWidth-10)

		modalMinWidth = Math.min(parseInt(@gallery.css('min-width')), modalWidth)

		@gallery.css({
			top: Math.max(10, parseInt(($(window).height()-Math.max(@panel.outerHeight(), sliderHeight))/2) )+'px',
			'min-width': modalMinWidth,
			width: modalWidth+'px',
			'margin-left': -parseInt(modalWidth/2)+'px'
		})
		@slider.css({width: sliderWidth+'px', height: sliderHeight+'px'})
		image.css({width: imageWidth+'px', height: imageHeight+'px'})

		@sliderInner.css({height: imageHeight+'px'})

		@panel.css({height: (@slider.outerHeight()-parseInt(@panel.css('padding-top'))-parseInt(@panel.css('padding-bottom')))+'px'})

		@

	_generateUid: () ->
		d = new Date()
		m = d.getMilliseconds() + ""
		++d + m + (if ++photoGalleryCounter == 10000 then (photoGalleryCounter = 1) else photoGalleryCounter)

	getNatural: (element) ->
		if typeof element.naturalWidth == 'undefined'
			img = new Image()
			img.src = element.src
			{ width: img.width, height: img.height }
		else
			{ width: element.naturalWidth, height: element.naturalHeight }
}
