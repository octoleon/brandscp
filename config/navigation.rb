SimpleNavigation::Configuration.run do |navigation|
  # Specify a custom renderer if needed.
  # The default renderer is SimpleNavigation::Renderer::List which renders HTML lists.
  # The renderer can also be specified as option in the render_navigation call.
  # navigation.renderer = Your::Custom::Renderer

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
    primary.item :dashboard, 'Dashboard', root_path(return: nil, phase: nil),  highlights_on: %r{/$}, link: { icon_class: 'icon-dashboard menubar-icon' }
    primary.item :events, 'Events', events_path(return: nil, phase: nil), highlights_on: %r{/events}, link: { icon_class: 'icon-events menubar-icon' }, if: proc { can?(:index, Event) }
    primary.item :tasks, 'Tasks', mine_tasks_path(return: nil, phase: nil), highlights_on: %r{/tasks}, link: { icon_class: 'icon-tasks menubar-icon' }, if: proc { can?(:index_my, Task) || can?(:index_team, Task) } do |secondary|
      secondary.item :mine_tasks, 'My Tasks', mine_tasks_path(return: nil, phase: nil), highlights_on: %r{/tasks/mine}, if: proc { can?(:index_my, Task) }
      secondary.item :team_tasks, 'Team Tasks', my_teams_tasks_path(return: nil, phase: nil), highlights_on: %r{/tasks/my_teams}, if: proc { can?(:index_team, Task) }
    end
    primary.item :venues, 'Venues', venues_path(return: nil, phase: nil), highlights_on: %r{/research/venues}, link: { icon_class: 'icon-venue menubar-icon' }, if: proc { can?(:index, Venue) }

    primary.item :brand_ambassadors, 'Brand Ambassadors', brand_ambassadors_root_path(return: nil, phase: nil), highlights_on: %r{/brand_ambassadors}, link: { icon_class: 'icon-campaign menubar-icon' }, if: proc { can?(:access, :brand_ambassadors) }
    primary.item :results, 'Results', results_reports_path(return: nil, phase: nil), highlights_on: %r{^/results}, link: { icon_class: 'icon-results menubar-icon' }, if: proc { can?(:access, :results) }
    primary.item :analysis, 'Analysis', analysis_path(return: nil, phase: nil), highlights_on: %r{/analysis}, link: { icon_class: 'icon-analysis menubar-icon' }, if: proc { can?(:access, :analysis ) }
  end
end
