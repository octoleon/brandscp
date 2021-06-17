class Api::V1::FormFieldsController < Api::V1::FilteredController
   inherit_resources
#  skip_authorization_check only: [:all,:add_activity_to_campaign,:add_activity_to_activity,:add_form_field_to_activity,:remove_sequence_from_activity_by_sequence,:modify_position_in_sequence_by_sequence_id,:add_condition_to_sequence]
  skip_authorization_check
  include NotificableController

  notifications_scope -> { current_company_user.notifications.events }

  resource_description do
    short 'CustomActivityForm'
    formats %w(json xml)
    error 400, 'Bad Request. The server cannot or will not process the request due to something that is perceived to be a client error.'
    error 404, 'Missing'
    error 401, 'Unauthorized access'
    error 500, 'Server crashed for some reason'
  end

  def show
	render json: FormFields.find(params[:id])
  end

  def create
    create! do |success, failure|
      success.json { render :show }
      success.xml { render :show }
      failure.json { render json: resource.errors, status: :unprocessable_entity }
      failure.xml { render xml: resource.errors, status: :unprocessable_entity }
    end
  end  

  def update
    update! do |success, failure|
      success.json { render json: resource}
      success.xml  { render :show }
      failure.json { render json: resource.errors, status: :unprocessable_entity }
      failure.xml  { render xml: resource.errors, status: :unprocessable_entity }
    end
  end  

  protected
  
  def permitted_params
    params.permit(form_fields: [:id,:fieldable_id, :name,:fieldable_type,:type,:ordering,:required,:settings,:form_field_options])[:form_fields]    
  end

  def skip_default_validation
    true
  end
    
end
