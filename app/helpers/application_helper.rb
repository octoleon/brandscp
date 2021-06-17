require 'base64'

module ApplicationHelper
  def present(model, format = :html)
    @presenters ||= {}
    format = format.to_s.capitalize
    @presenters[model.class] ||= "#{format}::#{model.class}Presenter".constantize.new(model, self) rescue nil
    @presenters[model.class] ||= "#{model.class}Presenter".constantize.new(model, self) rescue nil
    return model unless @presenters[model.class]
    # cache object so we dont create a new object when interacting through many objects
    # for example, when exporting thousands of records
    @presenters[model.class].model = model
    return @presenters[model.class] unless block_given?
    yield(@presenters[model.class])
  end

  def presenter
    @presenter ||= present(resource)
  end

  def place_address(place, link_name = false, line_separator = '<br />', name_separator = '<br />', concat_zip_code = false, concat_place_name = true)
    return if place.nil?
    place_name = place.name
    place_city = place.city

    if link_name
      venue = Venue.find_by(company_id: current_company.id, place_id: place.id)
      if venue.present?
        if place.name == place.city
          place_city = link_to place.city, venue_path(venue)
          place_name = nil
        else
          place_name = link_to place.name, venue_path(venue)
        end
      end
    end

    address = []
    city_parts = []
    #we compare street and formatted address street here
    formatted_addresses = place.formatted_address.split(',') unless place.formatted_address.nil?

    unless place.street.nil? || place.street.strip.empty? || place.name == place.street
      if formatted_addresses.present? && formatted_addresses[0].include?(place.street)
        address.push formatted_addresses[0].strip
      else
        address.push place.street
      end
    end

    city_parts.push place_city if place.city.present? && place.name != place.city
    city_parts.push place_city if place_name.nil? && address.empty? && place.city.present? && place.name == place.city

    if concat_zip_code
      state_zipcode = []
      state_zipcode.push place.state_code if place.state.present?
      state_zipcode.push place.zipcode if place.zipcode.present?
      city_parts.push state_zipcode.compact.join(' ') unless state_zipcode.empty?
    else
      city_parts.push place.state_code if place.state.present?
      city_parts.push place.zipcode if place.zipcode.present?
    end

    address.push city_parts.compact.join(', ') unless city_parts.empty? || !place.city
    address.push place.formatted_address if place.formatted_address.present? && city_parts.empty? && (place.city || !place.types.include?('political'))
    address_with_name = nil
    address_with_name = "<span class=\"address-name\">#{place_name}</span>" unless place_name.blank? || concat_place_name == false
    address_with_name = [address_with_name, address.compact.join(line_separator)].compact.join(name_separator) unless address.compact.empty?

    "<address>#{address_with_name}</address>".html_safe
  end

  def blank_state_module(module_name, &block)
    content_tag(:div, class: 'blank-state section-module') do
      content_tag(:h5, t("blank_states.modules.#{module_name}"), class: 'text-center') +
      (block_given? ? capture(&block) : ''.html_safe)
    end
  end

  def drag_drop_module(module_name, close_button_class = '', &block)
    content_tag(:div, id: "drag-drop-#{module_name}", class: "attachment-panel drag-drop-zone #{module_name}") do
      content_tag(:span, nil, class: "close #{close_button_class}") +
      content_tag(:div, class: 'attachment-select-file-view') do
        content_tag(:div, class: 'drag-box') do
          content_tag(:i, nil, class: 'icon-upload') +
          content_tag(:div, class: 'drag-box-text') do
            content_tag(:h5, 'DRAG & DROP') +
            content_tag(:p) do
              content_tag(:span, 'your ' + I18n.t("drag_n_drop.items.#{module_name}") + ' or ') +
              content_tag(:span, nil, class: 'file-browse') do
                ('browse' + file_field_tag('file', multiple: true, 'data-no-uniform' => 'true')).html_safe
              end
            end
          end
        end
      end +
      (block_given? ? capture(&block) : ''.html_safe)
    end
  end

  def icon_button_to(icon, options = {}, html_options = {})
    show_text = html_options.delete(:show_text)
    html_options[:class] ||= ''
    html_options[:class] = [html_options[:class], 'button-with-icon'].join(' ')
    html_options[:class] += ' button-with-icon-and-text' if show_text

    button_to options, html_options do
      content_tag(:i, nil, class: "icon #{icon}") +
      (show_text ? html_options[:title] : '')
    end
  end

  def button_to_add(title, url, options = {})
    icon_button_to 'icon-plus-sign-clear', url, options.merge(
      remote: true, method: :get,
      title: title, return: return_path,
      form_class: 'button_to button_to_add')
  end

  def button_to_edit(resource, title: nil, url: nil, remote: true)
    url ||= url_for([:edit, resource])
    title = I18n.t("buttons.edit.#{resource.class.name.underscore}")
    icon_button_to 'icon-edit', url,
                   remote: remote,
                   method: :get,
                   title: title,
                   return: return_path,
                   form_class: 'button_to button_to_edit'
  end

  def button_to_activate(resource, title: nil, url: nil)
    url ||= url_for([:activate, resource])
    icon_button_to 'icon-rounded-ok', url,
                   remote: true,
                   method: :get,
                   title: I18n.t("buttons.activate.#{resource.class.name.underscore}"),
                   form_class: 'button_to button_to_edit active-toggle-btn-' + resource.class.name.underscore.gsub('/', '_').downcase + '-' + resource.id.to_s
  end

  def button_to_deactivate(resource, title: nil, url: nil)
    url ||= url_for([:deactivate, resource])
    icon_button_to 'icon-rounded-disable', url,
                   remote: true,
                   method: :get,
                   title: I18n.t("buttons.deactivate.#{resource.class.name.underscore}"),
                   form_class: 'button_to button_to_edit active-toggle-btn-' + resource.class.name.underscore.gsub('/', '_').downcase + '-' + resource.id.to_s,
                   data: { confirm: I18n.t("confirm.deactivate.#{resource.class.name.underscore}",
                                           model: resource.class.model_name.human.downcase,
                                           name: resource.try(:name)),
                           url: url }
  end

  def button_to_destroy(resource, title: nil, url: nil)
    url ||= url_for([:destroy, resource])
    icon_button_to 'icon-rounded-disable', url,
                   remote: true,
                   method: :delete,
                   title: I18n.t("buttons.deactivate.#{resource.class.name.underscore}"),
                   form_class: 'button_to button_to_edit active-toggle-btn-' + resource.class.name.underscore.gsub('/', '_').downcase + '-' + resource.id.to_s,
                   data: { confirm: I18n.t("confirm.deactivate.#{resource.class.name.underscore}",
                                           model: resource.class.model_name.human.downcase,
                                           name: resource.try(:name)),
                           url: url }
  end

  def button_to_resend_invitation(resource, title: nil)
    icon_button_to 'icon-resend', resend_invite_company_user_path(resource),
                   remote: true,
                   method: :get,
                   title: I18n.t('buttons.invitations.resend'),
                   form_class: 'button_to button_to_resend_invitation',
                   data: { confirm: I18n.t('confirm.invitations.resend',
                                           model: resource.class.model_name.human.downcase),
                           url: resend_invite_company_user_path(resource) }
  end

  def button_to_activate_or_deactivate(resource, activate_url: nil, deactivate_url: nil)
    if resource[:active] || resource.active?
      button_to_deactivate(resource, title: nil, url: deactivate_url)
    else
      button_to_activate(resource, title: nil, url: activate_url)
    end
  end

  def event_place_address(event, _link_name = false, line_separator = '<br />', name_separator = '<br />')
    if event.current_place.present?
      street = "#{event.current_place.street_number} #{event.current_place.route}".strip
      address = []
      city_parts = []
      address.push street unless street.nil? || street.empty? || event.current_place.name == street
      city_parts.push event.current_place.city if event.current_place.city.present? && event.current_place.name != event.current_place.city
      city_parts.push event.current_place.state if event.current_place.state.present?
      city_parts.push event.current_place.zipcode if event.current_place.zipcode.present?

      address.push city_parts.compact.join(', ') unless city_parts.empty? || !event.current_place.city
      address_with_name = nil
      address_with_name = "<span class=\"address-name\">#{event.current_place.name}</span>" if event.current_place.name
      address_with_name = [address_with_name, address.compact.join(line_separator)].compact.join(name_separator) unless address.compact.empty?

      "<address>#{address_with_name}</address>".html_safe
    end
  end

  def resource_details_bar(title)
    content_tag(:div, id: 'resource-close-details', 'data-spy' => 'affix') do
      link_to(return_path || collection_path, class: 'close-details', title: title) do
        content_tag(:span, title, class: 'details-bar-pull-left') +
        content_tag(:span, ' '.html_safe, class: 'icon-close')
      end
    end
  end

  # Adds a script at the bottom of the page to reload the page
  # when the resource is edited
  def reload_page_on_edit_resource
    content_for :footer do
      javascript_tag <<-EOF
        $(document).on('#{resource.class.name.pluralize.underscore.gsub('/', '_')}:change', function(){
          window.location = '#{url_for params: { return: return_path }}'
        });
      EOF
    end
  end

  def rating_stars(rating)
    (rating.times.map do
      content_tag(:i, '', class: 'icon-star')
    end +
    (5 - rating).times.map do
      content_tag(:i, '', class: 'icon-star-empty')
    end).join.html_safe
  end

  def comment_date(comment)
    time_ago_in_words(comment.created_at)
  end

  def time_ago_in_words(the_date)
    unless the_date.nil?
      if the_date  <= 4.days.ago.end_of_day
        the_date.strftime('%b %e @ %l:%M %p')
      elsif the_date  <= 2.days.ago.end_of_day
        the_date.strftime('%A @ %l:%M %p')
      elsif the_date <= (Time.zone.now - 24.hours)
        the_date.strftime('Yesterday @ %l:%M %p')
      elsif the_date <= (Time.zone.now - 1.hours)
        hours = ((Time.zone.now - the_date)  / 3600).to_i
        if hours == 1
          'about an hour ago'
        else
          the_date.strftime("#{pluralize(hours, 'hour')} ago")
        end
      elsif the_date > (Time.zone.now - 1.hours) && the_date < Time.zone.now
        minutes = ((Time.zone.now - the_date)  / 60).to_i
        the_date.strftime("about #{pluralize(minutes, 'minute')} ago")
      end
    end
  end

  def format_date(the_date, plain = false)
    unless the_date.nil?
      if plain
        if the_date.strftime('%Y') == Time.zone.now.year.to_s
          the_date.strftime('%^a %b %e')
        else
          the_date.strftime('%^a %b %e, %Y')
        end
      else
        if the_date.strftime('%Y') == Time.zone.now.year.to_s
          the_date.strftime('%^a <b>%b %e</b>').html_safe
        else
          the_date.strftime('%^a <b>%b %e, %Y</b>').html_safe
        end
      end
    end
  end

  def format_time(the_date)
    the_date.strftime('%l:%M %P') unless the_date.nil?
  end

  def format_date_with_time(date, plain = false)
    if plain
      if date.strftime('%Y') == Time.zone.now.year.to_s
        date.strftime('%^a %b %e at %l:%M %p').html_safe unless date.nil?
      else
        date.strftime('%^a %b %e, %Y at %l:%M %p').html_safe unless date.nil?
      end
    else
      if date.strftime('%Y') == Time.zone.now.year.to_s
        date.strftime('%^a <b>%b %e</b> at %l:%M %p').html_safe unless date.nil?
      else
        date.strftime('%^a <b>%b %e, %Y</b> at %l:%M %p').html_safe unless date.nil?
      end
    end
  end

  def format_date_range(start_at, end_at, options = {})
    return if start_at.nil?
    return format_date_with_time(start_at) if end_at.nil?
    options[:date_separator] ||= '<br />'
    options[:date_only] ||= false

    if start_at.to_date != end_at.to_date
      if options[:date_only]
        format_date(start_at) +
        options[:date_separator].html_safe +
        format_date(end_at)
      else
        format_date_with_time(start_at) +
        options[:date_separator].html_safe +
        format_date_with_time(end_at)
      end
    else
      if start_at.strftime('%Y') == Time.zone.now.year.to_s
        the_date = start_at.strftime('%^a <b>%b %e</b>' + options[:date_separator]).html_safe
      else
        the_date = start_at.strftime('%^a <b>%b %e, %Y</b>' + options[:date_separator]).html_safe
      end
      the_date += "#{start_at.strftime('%l:%M %p').strip} - #{end_at.strftime('%l:%M %p').strip}".html_safe unless options[:date_only]
      the_date
    end
  end

  def user_new_feature(name, version = 1, &_block)
    return if current_company_user.dismissed_alert?(name, version)
    content_tag(:div, class: 'new-feature', 'data-alert' => name, 'data-version' => version) do
      if block_given?
        yield
      else
        build_new_feature_box name
      end
    end
  end

  def build_new_feature_box(name)
    content_tag(:h5, t("new_features.#{name}.title")) +
    link_to('', '#', class: 'close btn-dismiss-alert icon icon-close', title: 'Dismiss') +
    link_to(image_tag('video_arrow.png', width: 70, height: 70), '#',
            class: 'video-thumbnail', title: 'Play Video',
                                      data: { video: t("new_features.#{name}.video"),
                                              width: '640', height: '360' }) +
    content_tag(:div, t("new_features.#{name}.description").html_safe, class: 'feature-description')
  end

  def user_company_dropdown(user)
    companies = user.companies_active_role
    if companies.size == 1 || user.id != current_real_user.id
      link_to current_company.name, root_path, class: 'current-company-title'
    else
      content_tag(:div, class: 'header-menu dropdown header-menu') do
        link_to((current_company.name + ' ' + content_tag(:b, '', class: 'caret')).html_safe, root_path, class: 'dropdown-toggle current-company-title', 'data-toggle' => 'dropdown') +
        content_tag(:ul, class: 'dropdown-menu', id: 'user-company-dropdown', role: 'menu', 'aria-labelledby' => 'dLabel') do
          companies.map do |company|
            content_tag(:li, link_to(content_tag(:i, nil, class: 'icon-checked') + company.name, select_company_path(company),
                                     id: 'select-company-' + company.id.to_s),
                        role: 'presentation', class: (company.id == current_company.id ? ' active' : ''))
          end.join('').html_safe
        end
      end
    end
  end

  def gender_graph(data)
    return unless data.present? && data.values.max > 0

    content_tag(:div, class: :male) do
      content_tag(:div, class: 'percent') do
        content_tag(:span, "#{data.try(:[], 'Male').try(:round) || 0}") +
        content_tag(:span, '%', class: 'percent-sign')
      end +
      content_tag(:div, 'MALE', class: 'gender')
    end +
    content_tag(:div, class: :female) do
      content_tag(:div, class: 'percent') do
        content_tag(:span, "#{data.try(:[], 'Female').try(:round) || 0}") +
        content_tag(:span, '%', class: 'percent-sign')
      end +
      content_tag(:div, 'FEMALE', class: 'gender')
    end
  end

  def link_to_if_permitted(permission_action, subject_class, options, html_options = {}, &block)
    content = capture(&block)
    allowed = if subject_class.is_a?(Class)
                current_company_user.role.has_permission?(permission_action, subject_class)
    else
      can?(permission_action, subject_class)
    end
    link_to_if allowed, content, options, html_options do
      content_tag(:div, content, html_options)
    end
  end

  def campaigns_list_for_dropdown
    current_company.campaigns.accessible_by_user(current_company_user).active.order('name ASC').for_dropdown
  end

  def link_to_deactivate(model, opts = {})
    return unless model.active?
    opts[:url] ||= [:deactivate, model]
    link_to '', opts[:url],
            remote: true,
            title: I18n.t('confirmation.deactivate'),
            class: 'icon-rounded-disable',
            data: {
              confirm: I18n.t('confirmation.deactivate_confirm_message',
                              model: model.class.model_name.human.downcase) }
  end

  def active_class(item)
    item.active? ? 'active' : 'inactive'
  end

  def full_image_path(img_path)
    path = image_path(img_path)
    path = request.protocol + request.host_with_port + path unless ActionController::Base.asset_host
    path
  end

  def jbb_feature_enabled?
    current_company.id == 2
  end

  def default_params_for_view(default = '', scope: controller_name)
    if controller_name == 'dashboard'
      scope = 'visits'
    elsif controller_name == 'photos'
      scope = 'results_photos'
    elsif controller_name == 'expenses'
      scope = 'results_expenses'
    elsif controller_name == 'comments'
      scope = 'results_comments'
    else
      scope = controller_name
    end
    filter_string = CustomFilter.for_company_user(current_company_user).user_saved_filters
            .order('custom_filters.name ASC').by_type(scope).where(default_view: true).limit(1).pluck(:filters).first
    (filter_string || escape_query_params(default)).html_safe
  end

  def user_saved_filters(scope)
    CollectionFilter.new(scope, current_company_user, params).user_saved_filters
  end

  def escape_query_params(query)
    query.split('&').map { |p| CGI.escape(p).gsub('%3D', '=') }.join('&')
  end

  def step_navigation_bar(steps, active)
    content_tag :div, class: 'steps-wizard' do
      content_tag(:div, class: 'row-fluid') do
        steps.each_with_index.map do |step, i|
          step_class = (active == (i + 1) ? 'active' : (active > i ? 'completed' : ''))
          content_tag(:div, class: 'step span4 ' + step_class) do
            content_tag :div, class: 'step-box' do
              content_tag(:div, step, class: 'step-name') +
              content_tag(:div, nil, class: 'clearfix') +
              content_tag(:div, i + 1, class: 'circle-step')
            end
          end
        end.join.html_safe
      end +
      content_tag(:div,
                  content_tag(:div,
                              nil,
                              class: 'step-progress',
                              style: "width: #{100 / (steps.count - 1) * (active - 1)}%"),
                  class: 'step-line')
    end
  end
end
