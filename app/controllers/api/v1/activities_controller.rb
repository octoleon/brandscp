class Api::V1::ActivitiesController < Api::V1::ApiController
  inherit_resources
  skip_authorization_check only: [:index]
  skip_authorize_resource only: [:index]
  belongs_to :event, :venue, optional: true

  before_action :authorize_parent, except: [:new, :show]

  respond_to :json

  def_param_group :activity do
    param :activity, Hash, required: true, action_aware: true do
      param :activity_type_id, :number, required: true, desc: 'Activity Type ID'
      param :activity_date, %r{\A\d{1,2}/\d{1,2}/\d{4}\z}, required: true, desc: 'Activity date. Should be in format MM/DD/YYYY.'
      param :results_attributes, :event_result, required: false, desc: "A list of activity results with the id and value. Eg: results_attributes: [{id: 1, value:'Some value'}, {id: 2, value: '123'}]"
      param :company_user_id, :number, desc: 'Company user ID'
      param :campaign_id, :number, desc: 'Campaign ID'
      param :event_id, :number, desc: 'Event ID'
      param :venue_id, :number, desc: 'Venue ID'
    end
  end

  api :POST, '/api/v1/events/:event_id/activities', 'Create a new activity for a event'
  api :POST, '/api/v1/events/:venue_id/activities', 'Create a new activity for a venue'
  param_group :activity
  def create
    create! do |success, failure|
      success.json { render :show }
      success.xml { render :show }
      failure.json { render json: resource.errors, status: :unprocessable_entity }
      failure.xml { render xml: resource.errors, status: :unprocessable_entity }
    end
  end

  api :PUT, '/api/v1/events/:event_id/activities/:id', 'Update a event\'s activity details'
  api :PUT, '/api/v1/events/:venue_id/activities/:id', 'Update a venue\'s activity details'
  param :event_id, :number, required: false, desc: 'Event ID'
  param :venue_id, :number, required: false, desc: 'Venue ID'
  param :id, :number, required: true, desc: 'Activity ID'
  param_group :activity
  def update
    update! do |success, failure|
      success.json { render :show }
      success.xml { render :show }
      failure.json { render json: resource.errors, status: :unprocessable_entity }
      failure.xml { render xml: resource.errors, status: :unprocessable_entity }
    end
  end

  api :GET, '/api/v1/events/:event_id/activities/:id/deactivate', 'Deactivate a event\'s activity'
  api :GET, '/api/v1/events/:venue_id/activities/:id/deactivate', 'Deactivate a venue\'s activity'
  param :event_id, :number, required: false, desc: 'Event ID'
  param :venue_id, :number, required: false, desc: 'Venue ID'
  param :id, :number, required: true, desc: 'Activity ID'

  def deactivate
    authorize! :deactivate, Activity
    resource.deactivate!
    render json: 'ok'
  end

  api :GET, '/api/v1/events/:event_id/activities', 'Get a list of activities for an Event'
  api :GET, '/api/v1/events/:venue_id/activities', 'Get a list of activities for an Venue'
  param :event_id, :number, required: false, desc: 'Event ID'
  param :venue_id, :number, required: false, desc: 'Venue ID'
  description <<-EOS
    Returns a full list of the associated activity types for a campaign
  EOS
  example <<-EOS
  {
    "data": [
      {
        "id": 5135,
        "activity_type_id": 27,
        "activity_type_name": "Jameson BA POS Drop FY15",
        "activity_date": "2015-02-06T02:00:00.000-06:00",
        "company_user_name": "Chris Jaskot"
      }
    ]
  }
  EOS
  def index
    authorize!(:show, Activity)
    collection
  end

  api :GET, '/api/v1/actvities/new', 'Return a list of fields for a new activity of a given activity type'
  param :activity_type_id, :number, required: true, desc: 'The activity type id'
  description <<-EOS
    Returns a full list of the associated activity types for a campaign
  EOS
  def new
    respond_to do |format|
      format.json do
        render json: {
          activity_date: resource.activity_date,
          company_user: {
            id: resource.company_user.id,
            name: resource.company_user.full_name
          },
          activity_type: {
            id: activity_type.id,
            name: activity_type.name
          },
          data: serialize_fields_for_new(activity_type.form_fields)
        }
      end
    end
  end

  api :GET, '/api/v1/actvities/:id', 'Return a list of fields with results for an existing activity'
  description <<-EOS
    Returns a full list of the associated activity types for a campaign
  EOS
  def show
    authorize! :show, resource.activitable
    results = resource.form_field_results
    results.each { |r| r.save(validate: false) if r.new_record? }
    respond_to do |format|
      format.json do
        render json: {
          id: resource.id,
          activity_date: resource.activity_date,
          campaign: {
            id: resource.campaign_id,
            name: resource.campaign_name
          },
          company_user: {
            id: resource.company_user.id,
            name: resource.company_user.full_name
          },
          activity_type: {
            id: resource.activity_type.id,
            name: resource.activity_type.name
          },
          activitable: {
            id: resource.activitable_id,
            type: resource.activitable_type
          },
          data: serialize_fields_for_edit(resource.form_field_results)
        }
      end
    end
  end

  api :GET, '/api/v1/events/:event_id/actvities/form', 'Returns a list of requred fields for uploading a file to S3'
  description <<-EOS
  This method returns all the info required to make a POST to Amazon S3 to upload a new file. The key sent to S3 should start with
  /uploads and has to be created into a new folder with a unique generated name. Ideally using a GUID. Eg:
  /uploads/9afa6775-2c8e-44f8-9cda-280e80446ced/My file.jpg

  The signature will expire 1 hour after it's generated, therefore, it's recommended to not cache these fields for long time.
  EOS
  def form
    bucket = AWS::S3.new.buckets[ENV['S3_BUCKET_NAME']]
    form = bucket.presigned_post(acl: 'public-read', success_action_status: 201)
           .where(:key).starts_with('uploads/')
    data = { fields: form.fields, url: "https://s3.amazonaws.com/#{ENV['S3_BUCKET_NAME']}/"  }
    respond_to do |format|
      format.json { render json: data }
      format.xml { render xml: data }
    end
  end

  protected

  def activity_type
    current_company.activity_types.find(params[:activity_type_id]) if params[:activity_type_id].present?
  end

  def serialize_fields_for_new(fields)
    fields.map do |field|
      serialize_field field
    end
  end

  def serialize_fields_for_edit(results)
    results.map do |result|
      field = result.form_field
      serialize_field(field, result)
    end
  end

  def serialize_field(field, result = nil)
    field.format_json(result)
  end

  def activity_params
    params.require(:activity).permit([
      :activity_type_id, {
        results_attributes: [:id, :form_field_id, :value, { value: [] }, :_destroy] },
      :campaign_id, :company_user_id, :activity_date]).tap do |whielisted|
      unless whielisted.nil? || whielisted[:results_attributes].nil?
        whielisted[:results_attributes].each_with_index do |value, k|
          value[:value] = params[:activity][:results_attributes][k][:value]
        end
      end
    end
  end

  def collection
    @activities ||= end_of_association_chain.where(active: true)
  end

  def authorize_parent
    authorize!(:show, parent)
  end
end
