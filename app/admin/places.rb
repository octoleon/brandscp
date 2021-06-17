ActiveAdmin.register Place do
  config.clear_action_items!
  actions :index, :show, :edit, :update

  filter :name
  filter :city
  filter :state
  filter :country, as: :select, collection: proc { Country.all }
  filter :zipcode
  filter :td_linx_code

  form do |f|
    f.inputs 'Details' do
      f.input :name
    end

    f.inputs 'Address' do
      f.input :formatted_address
      f.input :street_number, label: 'Address 1'
      f.input :route,  label: 'Address 2'
      f.input :zipcode
      f.input :city
      f.input :state
      f.input :country
      f.input :td_linx_code
    end
    f.actions
  end

  index do
    id_column
    column :name
    column :city
    column :state
    column :country
    column :types do |place|
      place.types.join(', ') unless place.types.nil?
    end
    column :venues do |place|
      place.venues.joins(:company).includes(:company).map do |venue|
        "#{venue.id} - "  + link_to(venue.company.name, venue_path(venue))
      end.join('<br />').html_safe
    end
    actions

  end

  csv do
    column :td_linx_code
    column :name
    column :street
    column :city
    column :state
    column :country
    column :types do |place|
      place.types.join(', ') unless place.types.nil?
    end
    column :price_level
    column :phone_number
  end

  controller do
    def permitted_params
      params.permit(place: [:name, :formatted_address, :street_number, :route, :zipcode, :city, :state, :country, :td_linx_code])
    end
  end
end
