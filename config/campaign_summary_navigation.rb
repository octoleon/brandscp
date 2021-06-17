SimpleNavigation::Configuration.run do |navigation|
  # Specify a custom renderer if needed.
  # The default renderer is SimpleNavigation::Renderer::List which renders HTML lists.
  # The renderer can also be specified as option in the render_navigation call.
  navigation.renderer = SimpleNavigationBootstrap

  # Specify the class that will be applied to active navigation items. Defaults to 'selected'
  # navigation.selected_class = 'your_selected_class'
  navigation.selected_class = 'active'

  # Specify the class that will be applied to the current leaf of
  # active navigation items. Defaults to 'simple-navigation-active-leaf'
  # navigation.active_leaf_class = 'your_active_leaf_class'

  # Item keys are normally added to list items as id.
  # This setting turns that off
  # navigation.autogenerate_item_ids = false

  # You can override the default logic that is used to autogenerate the item ids.
  # To do this, define a Proc which takes the key of the current item as argument.
  # The example below would add a prefix to each key.
  # navigation.id_generator = Proc.new {|key| "my-prefix-#{key}"}

  # If you need to add custom html around item names, you can define a proc that will be called with the name you pass in to the navigation.
  # The example below shows how to wrap items spans.
  # navigation.name_generator = Proc.new {|name| "<span>#{name}</span>"}

  # The auto highlight feature is turned on by default.
  # This turns it off globally (for the whole plugin)
  # navigation.auto_highlight = false
  navigation.items do |primary|
    primary.item :group_by, '', 'javascript:void(0);', class: 'header-menu', link: { 'class' => 'dropdown-toggle', 'data-toggle' => 'dropdown' } do |secondary|
      secondary.item :status, I18n.translate(:'analysis.campaign_summary.group_status'), 'javascript:void(0);', class: 'group-item'
      secondary.item :campaign, I18n.translate(:'analysis.campaign_summary.group_campaign'), 'javascript:void(0);', class: 'group-item', link: { icon_class: 'icon-campaign-flag pull-left' }
      secondary.item :area, I18n.translate(:'analysis.campaign_summary.group_area'), 'javascript:void(0);', class: 'group-item', link: { icon_class: 'icon-venue pull-left' }
      secondary.item :people, I18n.translate(:'analysis.campaign_summary.group_people'), 'javascript:void(0);', class: 'group-item', link: { icon_class: 'icon-user pull-left' }
    end
  end
end
