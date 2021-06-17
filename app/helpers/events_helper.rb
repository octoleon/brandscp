module EventsHelper
  include ActionView::Helpers::NumberHelper
  include SurveySeriesHelper

  def update_event_details_bar(event)
    presenter = present(event)
    contents = presenter.render_nav_phases
    "
      $('#phases-container').html('#{j contents }');
      $('body').scrollmultispy('destroy');
      #{create_scrollmultispy_js}
      $(window).trigger('scroll');
    \n".html_safe
  end

  def valid_to_submit_message(event)
    "window.EventDetails.showMessage('#{I18n.t('instructive_messages.results.completed')}', 'blue', false, true);".html_safe if event.valid_to_submit?
  end

  def editable_invite_checkbox(resource, invite, attribute)
    readonly = can?(:edit_invite, resource)
    simple_form_for([resource, invite], remote: true) do |f|
      f.input attribute, label: false, as: :boolean, input_html: { title: I18n.t(attribute, scope: [:activerecord, :attributes, invite.class.name.underscore.to_sym]) }
    end
  end

  def editable_invite_attribute(resource, invite, attribute)
    return invite.send(attribute) unless can? :edit_invite, resource
    content_tag :span, invite.send(attribute), class: 'has-popover invite-editable-attribute', data: { trigger: 'click', placement: :bottom, content: invite_attribute_popover(resource, invite, attribute) }, rel: :popover
  end

  def invite_attribute_popover(resource, invite, attribute)
    html_escape_once(simple_form_for([resource, invite], remote: true) do |f|
      content_tag :div, class: 'row-fluid' do
        content_tag(:div, content_tag(:a, '', href: "#", class: 'icon icon-minus-rounded decrease', title: 'Decrease'), class: 'span2') +
        content_tag(:div, '-', class: 'span8') do
          f.input attribute, label: false
        end +
        content_tag(:div, content_tag(:a, '', href: "#", class: 'icon icon-plus-sign increase', title: 'Increase'), class: 'span2')
      end
    end)
  end

  def create_scrollmultispy_js
    "
      $('body').scrollmultispy({
          target: '.event-details-scroll-spy',
          offset: 200
      });
    ".html_safe
  end

  def kpi_goal_progress_bar(goal, result)
    return unless goal.present?
    result ||= 0
    bar_widht = [100, result * 100 / goal].min
    bar_widht = 1 if result > 0 && bar_widht < 1   # Display at least one or two pixels
    content_tag(:div, class: 'progress') do
      content_tag(:div, '', class: 'bar', style: "width: #{bar_widht}%")
    end
  end

  def contact_info_tooltip(contact)
    details = contact_details(contact)
    details =
      if details.any?
        content_tag(:ul, class: 'unstyled contact-info') do
          details.map { |d| content_tag(:li, tag(:i, class: d[:icon]) + d[:txt]) }.join.html_safe
        end
      else
        ''.html_safe
      end
    content_tag(:div, class: 'contacts-tooltip') do
      content_tag(:h6, contact.full_name, class: 'contact-name') +
      content_tag(:span, (contact.respond_to?(:title) ? contact.title : contact.role_name), class: 'contact-role') +
      details
    end
  end

  def contact_details(contact)
    [].tap do |a|
      a.push(
        icon: 'icon-wired-email',
        txt: link_to(contact.email, "mailto:#{contact.email}")) unless contact.email.blank?
      a.push(
        icon: 'icon-mobile',
        txt: link_to(contact.phone_number, "tel:#{contact.phone_number}")) unless contact.phone_number.blank?
      address = [contact.street_address, contact.city, contact.state, contact.country_name].delete_if(&:blank?).join(', ')
      a.push(
        icon: 'icon-wired-venue',
        txt: link_to(address, "https://maps.google.com?daddr=#{address}", target: '_blank')) unless address.blank?
    end
  end

  def describe_before_event_alert(resource)
    description = 'Your event is scheduled.'
    alert_parts = []
    if can?(:view_members, resource) && (can?(:add_members, resource) || can?(:delete_member, resource))
      alert_parts.push "<a href=\"#event-members\" class=\"smooth-scroll\">manage the event team</a>"
    end
    if can?(:tasks, resource)
      alert_parts.push "<a href=\"#event-tasks\" class=\"smooth-scroll\">complete tasks</a>"
    end
    if can?(:index_documents, resource) && can?(:create_document, resource)
      alert_parts.push "<a href=\"#event-documents\" class=\"smooth-scroll\">upload event documents</a>"
    end
    description += ' You can ' + alert_parts.compact.to_sentence unless alert_parts.empty?
    description.html_safe
  end

  def event_phases_and_steps_for_api(event)
    phases = event.phases
    phases.merge!(
      phases: Hash[phases[:phases].map do |k, steps|
                     [k, steps.select { |s| !s.key?(:if) || instance_exec(event, &s[:if]) }.map { |s| s.reject { |k, _v| k == :if } }]
                   end]
    )
    # Make sure that the user is allowed to perform the next step
    phases.merge!(
      next_step: phases[:phases][phases[:current_phase]].find { |p| p[:complete] == false }
    )
  end

  def module_range_val(event, module_name, range_name)
    return nil unless event.campaign.range_module_settings?(module_name)
    event.campaign.module_setting(module_name, range_name).to_i
  end

  def describe_today_event_alert(resource)
    description = 'Your event is scheduled for today. '
    alert_parts = []
    alert_parts.push "<a href=\"#event-results-form\" class=\"smooth-scroll\">enter post event data</a>" if can?(:view_data, resource) && can?(:edit_data, resource)
    alert_parts.push "<a href=\"#event-photos\" class=\"smooth-scroll\">upload photos</a>" if resource.campaign.enabled_modules.include?('photos') && can?(:photos, resource) && can?(:create_photo, resource)
    alert_parts.push "<a href=\"#event-surveys\" class=\"smooth-scroll\">conduct surveys</a>" if resource.campaign.enabled_modules.include?('surveys') && can?(:surveys, resource) && can?(:create_survey, resource)
    alert_parts.push "<a href=\"#event-expenses\" class=\"smooth-scroll\">enter expenses</a>" if resource.campaign.enabled_modules.include?('expenses') && can?(:expenses, resource) && can?(:create_expense, resource)
    alert_parts.push "<a href=\"#event-comments\" class=\"smooth-scroll\">gather comments</a>" if resource.campaign.enabled_modules.include?('comments') && can?(:comments, resource) && can?(:create_comment, resource)
    unless alert_parts.empty?
      description += 'Please ' + alert_parts.compact.to_sentence + ' from your audience during or shortly after the event.'
    end
    description.html_safe
  end

  def describe_due_event_alert(resource)
    description = 'Your post event report is due. '
    alert_parts = []
    alert_parts.push "<a href=\"#event-results-form\" class=\"smooth-scroll\">enter post event data</a>" if can?(:view_data, resource) && can?(:edit_data, resource)
    alert_parts.push "<a href=\"#event-photos\" class=\"smooth-scroll\">upload photos</a>" if resource.campaign.enabled_modules.include?('photos') && can?(:photos, resource) && can?(:create_photo, resource)
    alert_parts.push "<a href=\"#event-surveys\" class=\"smooth-scroll\">conduct surveys</a>" if resource.campaign.enabled_modules.include?('surveys') && can?(:surveys, resource) && can?(:create_survey, resource)
    alert_parts.push "<a href=\"#event-expenses\" class=\"smooth-scroll\">enter expenses</a>" if resource.campaign.enabled_modules.include?('expenses') && can?(:expenses, resource) && can?(:create_expense, resource)
    alert_parts.push "<a href=\"#event-comments\" class=\"smooth-scroll\">gather comments</a>" if resource.campaign.enabled_modules.include?('comments') && can?(:comments, resource) && can?(:create_comment, resource)
    unless alert_parts.empty?
      description += 'Please ' + alert_parts.compact.to_sentence + ' now.'
    end
    description.html_safe
  end

  def describe_late_event_alert(resource)
    description = 'Your post event report is late. '
    alert_parts = []
    alert_parts.push "<a href=\"#event-results-form\" class=\"smooth-scroll\">submit post event data</a>" if can?(:view_data, resource) && can?(:edit_data, resource)
    alert_parts.push "<a href=\"#event-photos\" class=\"smooth-scroll\">upload photos</a>" if resource.campaign.enabled_modules.include?('photos') && can?(:photos, resource) && can?(:create_photo, resource)
    alert_parts.push "<a href=\"#event-surveys\" class=\"smooth-scroll\">complete surveys</a>" if resource.campaign.enabled_modules.include?('surveys') && can?(:surveys, resource) && can?(:create_survey, resource)
    alert_parts.push "<a href=\"#event-expenses\" class=\"smooth-scroll\">enter expenses</a>" if resource.campaign.enabled_modules.include?('expenses') && can?(:expenses, resource) && can?(:create_expense, resource)
    alert_parts.push "<a href=\"#event-comments\" class=\"smooth-scroll\">enter comments</a>" if resource.campaign.enabled_modules.include?('comments') && can?(:comments, resource) && can?(:create_comment, resource)
    unless alert_parts.empty?
      description += 'Please ' + alert_parts.compact.to_sentence + ' now.'
    end
    description.html_safe
  end

  def describe_filters(resource_name = nil)
    tags = FilterTags.new(params, current_company_user).tags do |label, filter_name, expandible, _param|
      remove_data = { filter: filter_name }
      if /\Adate:(?<start_date>.*),(?<end_date>.*)\z/ =~ filter_name
        remove_data = { filter: 'date', start_date: start_date, end_date: end_date }
      end
      content_tag(:div,  class: 'filter-item') do
        (if expandible
           link_to('', '#', class: 'icon icon-plus', title: 'Expand this filter',
                            data: { filter: filter_name })
         else
           ''.html_safe
         end) +
        label.html_safe + ' ' + link_to('', '#', class: 'icon icon-close',
                                           title: 'Remove this filter',
                                           data: remove_data)
      end if label.present?
    end.join(' ').strip

    self.builder_block = builder_block if block_given?
    if resource_name.present? || resource_class.present?
      resource_name ||= resource_class.model_name.human.downcase
      tags = "#{tags}" unless tags.blank?
      [
        '<span class="results-count">' + number_with_delimiter(collection_count) + ' ' +
        resource_name.pluralize(collection_count),
        'found for: </span>',
        tags
      ].compact.join(' ').strip.html_safe
    else
      "<span class='without-counter-title'>FILTERED TO:</span><br /> #{tags}".html_safe unless tags.blank?
    end
  end

  def allowed_campaigns(venue = nil, conditions: nil)
    campaigns = company_campaigns.active.accessible_by_user(current_company_user)
    campaigns = campaigns.where *conditions if conditions
    if venue.present? && !current_company_user.is_admin?
      campaigns.select { |c| c.place_allowed_for_event?(venue.place) }.map { |c| [c.name, c.id] }
    else
      campaigns.for_dropdown
    end
  end

  def event_date(event, attribute)
    event.send(attribute)
  end
end
