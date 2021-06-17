class Api::V1::CampaignCustomActivityFormsController < Api::V1::FilteredController
   inherit_resources
  skip_authorization_check only: [:all_campaign_activities]
  include NotificableController

  notifications_scope -> { current_company_user.notifications.events }

  resource_description do
    short 'CampaignCustomActivityForms'
    formats %w(json xml)
    error 400, 'Bad Request. The server cannot or will not process the request due to something that is perceived to be a client error.'
    error 404, 'Missing'
    error 401, 'Unauthorized access'
    error 500, 'Server crashed for some reason'
  end
  
  def show
	render json: CampaignCustomActivityForm.find(params[:id])
  end
    	
  def all_campaign_activities
	render json: CampaignCustomActivityForm.where('campaign_id = ?',params[:campaign_custom_activity_form_id])
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
      success.json { render :show }
      success.xml  { render :show }
      failure.json { render json: resource.errors, status: :unprocessable_entity }
      failure.xml  { render xml: resource.errors, status: :unprocessable_entity }
    end
  end  

    
  protected
  
  def permitted_params
    params.permit(campaign_custom_activity_form: [:custom_activity_form_id, :campaign_id])[:campaign_custom_activity_form]
  end
  
end
