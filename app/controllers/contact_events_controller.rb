# Contact Events Controller class
#
# This class handle the requests for managing the Contact Events
#
class ContactEventsController < InheritedResources::Base
  belongs_to :event

  actions :new, :create, :destroy, :update, :edit

  custom_actions collection: [:add, :list]

  before_action :copy_of_destroyed, only: [:destroy]

  defaults resource_class: ContactEvent

  load_and_authorize_resource

  before_action do
    authorize! :show, parent
  end

  respond_to :js

  def add
  end

  def create
    create! do |success, _failure|
      success.js do
        session["create_count_#{params[:form_id]}"] ||= 0
        @count = session["create_count_#{params[:form_id]}"] += 1
      end
    end
  end

  def list
    @contacts = ContactEvent.contactables_for_event(parent, params[:term])
    render layout: false
  end

  protected

  def copy_of_destroyed
    @contact = resource
  end

  def build_resource(*args)
    @contact_event ||= super
    @contact_event.build_contactable if action_name == 'new' && @contact_event.contactable.nil?
    @contact_event
  end

  def build_resource_params
    [permitted_params || {}]
  end

  def permitted_params
    params.permit(
      contact_event: [
        :id, :contactable_id, :contactable_type,
        { contactable_attributes: [
          :id, :street1, :street2, :city, :company_id, :country, :email, :first_name,
          :last_name, :phone_number, :state, :company_name, :title, :zip_code] }])[:contact_event]
  end

  def modal_dialog_title
    I18n.translate(
      "modals.title.#{resource.contactable.new_record? ? 'new' : 'edit'}.contact_event")
  end
end
