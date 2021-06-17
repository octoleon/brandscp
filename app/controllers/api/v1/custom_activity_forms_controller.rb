class Api::V1::CustomActivityFormsController < Api::V1::FilteredController
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
	render json: CustomActivityForm.find(params[:id])
  end
    	
  def all
	render json: current_company.custom_activity_forms
  end
  
  def all_assigned
	render json: current_company.campaigns.custom_activity_forms
  end

  def_param_group :custom_form_activity do
 #   param :name, String, required: true, desc: 'Title of the Activity'
    param :description, String, required: false, desc: 'Description of the Activity'
    param :allowMultipleEntries, :bool, required: false, desc: "Can the activity be answered multiple times?"
    param :showInQuickActions, :bool, required: false, desc: "Should the activity be available in the quick actions"
  end

  api :POST, '/api/v1/custom_activity_forms', 'Create a new activity'
  param_group :custom_form_activity      
#  param :company_id, :number, required: true, desc: 'Company ID'
  def create
    create! do |success, failure|
      success.json { render :show }
      success.xml { render :show }
      failure.json { render json: resource.errors, status: :unprocessable_entity }
      failure.xml { render xml: resource.errors, status: :unprocessable_entity }
    end
  end  

  api :PUT, '/api/v1/custom_activity_forms/:id', 'Update a custom_form_activity\'s details'
  #param :id, :number, required: true, desc: 'Custom Form Activity ID'
  param_group :custom_form_activity
  def update
    update! do |success, failure|
      success.json { render json: resource }
      success.xml  { render :show }
      failure.json { render json: resource.errors, status: :unprocessable_entity }
      failure.xml  { render xml: resource.errors, status: :unprocessable_entity }
    end
  end  

  api :POST, '/api/v1/custom_activity_forms/:id/add_activity_to_campaign', 'Add an activity to a campaign'
  param :id, :number, required: true, desc: 'Custom Form Activity ID'
  param :campaign_id, :number, required: true, desc: 'Campaign ID'
  def add_activity_to_campaign
    @currentform=CustomActivityForm.find(params[:id])
    @campaignforms=CampaignCustomActivityForm.where('custom_activity_form_id=? AND  campaign_id!=?', params[:id],params[:campaign_id])
  	
  	if @campaignforms.count >0
  	  result = { success: false,
  	  	info: 'Activity used in different campaign already.',
  	  	data: {} }
      render json: result, status: :unprocessable_entity
    else
  	  @ccaf=@currentform.campaign_custom_activity_forms.create(:campaign_id=>params[:campaign_id])
  	  render json: @ccaf
  	end
  end

  api :POST, '/api/v1/custom_activity_forms/:id/add_activity_to_activity', 'Add an activity to an activity'
 # param :id, :number, required: true, desc: 'Activity ID (to add to)'
 # param :activity_id_2, :number, required: true, desc: 'Activity ID (to add)'
  param :sequence, :number, required: false, desc: 'Step/Sequence number the activity should be placed at'
  def add_activity_to_activity
    @currentform=CustomActivityForm.find(params[:id])
    maxsequence=CustomActivitySequence.where('custom_activity_form_id=?',params[:id]).maximum("sequence")
    if maxsequence.nil?
    	@newseq=@currentform.custom_activity_sequences.create(:sequence=>1,:context=>'ACTIVITY',:reference_id=>params[:activity_id_2])
	  	render json: @newseq
	  else 
	  	if params[:sequence].nil? || params[:sequence].to_i>maxsequence
	  	  maxsequence=maxsequence+1
		  @newseq=@currentform.custom_activity_sequences.create(:sequence=>maxsequence,:context=>'ACTIVITY',:reference_id=>params[:activity_id_2])
		  render json: @newseq
		else
		  @currentform.custom_activity_sequences.where('sequence>=?',params[:sequence].to_i).update_all('sequence=sequence+1')
		  @newseq=@currentform.custom_activity_sequences.create(:sequence=>params[:sequence].to_i,:context=>'ACTIVITY',:reference_id=>params[:activity_id_2])
	  	  render json: @newseq
		end
	end
  end

  api :POST, '/api/v1/custom_activity_forms/:id/add_form_field_to_activity', 'Add an form field to an activity'
 # param :id, :number, required: true, desc: 'Activity ID to add to'
 # param :form_field_id, :number, required: true, desc: 'Form Field ID to add'
  param :sequence, :number, required: false, desc: 'Step/Sequence number the form field should be placed at'  
  def add_form_field_to_activity
    @currentform=CustomActivityForm.find(params[:id])
    maxsequence=CustomActivitySequence.where('custom_activity_form_id=?',params[:id]).maximum("sequence")
    if maxsequence.nil?
    	@newseq=@currentform.custom_activity_sequences.create(:sequence=>1,:context=>'FORM_FIELD',:reference_id=>params[:form_field_id])
	  	render json: @newseq
	else 
	  if params[:sequence].nil? || params[:sequence].to_i>maxsequence
	    maxsequence=maxsequence+1
	    @newseq=@currentform.custom_activity_sequences.create(:sequence=>maxsequence,:context=>'FORM_FIELD',:reference_id=>params[:form_field_id])
		render json: @newseq
	  else
		@currentform.custom_activity_sequences.where('sequence>=?',params[:sequence].to_i).update_all('sequence=sequence+1')
		@newseq=@currentform.custom_activity_sequences.create(:sequence=>params[:sequence].to_i,:context=>'FORM_FIELD',:reference_id=>params[:form_field_id])
	  	render json: @newseq
	  end
	end
  end

  api :POST, '/api/v1/custom_activity_forms/:id/remove_sequence_from_activity_by_sequence', 'Remove a sequence from an activity'
 # param :id, :number, required: true, desc: 'Activity ID to modify'
  #param :sequence, :number, required: true, desc: 'Step/Sequence number to remove'    
  def remove_sequence_from_activity_by_sequence
    @currentform=CustomActivityForm.find(params[:id])
    @currentseq=@currentform.custom_activity_sequences.where('sequence=?',params[:sequence].to_i)
    if @currentseq.count>0
      @currentseq.destroy_all
      @currentform.custom_activity_sequences.where('sequence>?',params[:sequence].to_i).update_all('sequence=sequence-1')
  	  result = { success: true,
  	  	info: 'Sequence removed.',
  	  	data: {} }
      render json: result
    else
   	  result = { success: false,
  	  	info: 'Sequence not found.',
  	  	data: {} }
      render json: result, status: :unprocessable_entity   
    end
  end

  api :POST, '/api/v1/custom_activity_forms/:id/remove_sequence_from_activity_by_sequence_id', 'Remove a sequence from an activity'
 # param :id, :number, required: true, desc: 'Activity ID to modify'
  #param :sequence, :number, required: true, desc: 'Step/Sequence number to remove'    
  def remove_sequence_from_activity_by_sequence_id
    @currentform=CustomActivityForm.find(params[:id])
    @currentseq=@currentform.custom_activity_sequences.find(params[:sequence_id].to_i)
    
    if @currentseq.present?
      @currentform.custom_activity_sequences.where('sequence>?',@currentseq.sequence).update_all('sequence=sequence-1')
      @currentseq.delete

  	  result = { success: true,
  	  	info: 'Sequence removed.',
  	  	data: {} }
      render json: result
    else
   	  result = { success: false,
  	  	info: 'Sequence not found.',
  	  	data: {} }
      render json: result, status: :unprocessable_entity   
    end
  end
  
  api :POST, '/api/v1/custom_activity_forms/:id/modify_position_in_sequence_by_sequence_id', 'Modify the step/sequnce of an existing sequence in an activity'
  #param :id, :number, required: true, desc: 'Activity ID to add to'
  #param :sequence_id, :number, required: true, desc: 'Step/Sequence number to modify'     
  #param :new_sequence, :number, required: true, desc: 'New Step/Sequence position'     
  def modify_position_in_sequence_by_sequence_id
    @currentform=CustomActivityForm.find(params[:id])
    @currentseq=@currentform.custom_activity_sequences.where('id=?',params[:sequence_id].to_i)
    max_sequence=CustomActivitySequence.where('custom_activity_form_id=?',params[:id]).maximum("sequence")

    if @currentseq.count>0
      new_sequence=params[:new_sequence].to_i
      if max_sequence<new_sequence
      	new_sequence=max_sequence
      end
      
      currpos=@currentform.custom_activity_sequences.find(params[:sequence_id].to_i).sequence
      @currentform.custom_activity_sequences.where('sequence>?',currpos).update_all('sequence=sequence-1')
      @currentform.custom_activity_sequences.where('sequence>?',new_sequence).update_all('sequence=sequence+1')
      @currentform.custom_activity_sequences.where('id=?',params[:sequence_id].to_i).update_all(sequence: new_sequence)
      
  	  result = { success: true,
  	  	info: 'Sequence moved.',
  	  	data: {} }
      render json: currpos
    else
   	  result = { success: false,
  	  	info: 'Sequence not found.',
  	  	data: {} }
      render json: result, status: :unprocessable_entity   
    end
  end

  api :POST, '/api/v1/custom_activity_forms/:id/add_condition_to_sequence', 'Add a condition to a sequence'
  #param :id, :number, required: true, desc: 'Activity ID to modify'
  #param :custom_activity_sequence_id, :number, required: true, desc: 'Step/Sequence number to add condition to' 
  #param :sequence_id_value_dependent_on, :number, required: true, desc: 'Step/Sequence number the condition is dependent on' 
  #param :operator, String, required: true, desc: 'Operatation that will be used (is/is not)' 
  #param :condition, String, required: true, desc: 'Condition that will be determined ([LOCK]/[UNLOCK])' 
  #param :value, String, required: true, desc: 'Value of operator that must be met' 
  description <<-EOS
  	Example submission:
    {
	"sequence_id":"10",
	"sequence_id_dependent":"9",
	"operator":"is",
	"condition":"[LOCK]",
	"value":"test"
	}
	EOS
	 
  def add_condition_to_sequence
    @currentform=CustomActivityForm.find(params[:id])
    @currentseq=@currentform.custom_activity_sequences.where('id=?',params[:sequence_id].to_i)
    @conditional=@currentseq.first.custom_activity_conditions.create(:custom_activity_sequence_id=>params[:custom_activity_sequence_id],:sequence_id_dependent_on=>params[:sequence_id_dependent_on],:sequence_id_value_dependent_on=>params[:sequence_id_value_dependent_on],:operator=>params[:operator],:condition=>params[:condition],:value=>params[:value])
	render json: @conditional
  end

  api :POST, '/api/v1/custom_activity_forms/:id/remove_condition_from_sequence', 'Remove a condition from a sequence'
  param :id, :number, required: true, desc: 'Activity ID to modify'
  param :sequence_id, :number, required: true, desc: 'ID of Step/Sequence number to remove condition from' 
  param :condition_id, :number, required: true, desc: 'ID of condition to remove' 
  description <<-EOS
  	Example submission:
	{
	"sequence_id":"10",
	"condition_id":"8"
	}
	EOS
	
  def remove_condition_from_sequence
    @currentform=CustomActivityForm.find(params[:id])
    @currentseq=@currentform.custom_activity_sequences.where('id=?',params[:sequence_id].to_i)
    if @currentseq.count>0
      @currentconditions=@currentseq.first.custom_activity_conditions.where('id=?',params[:condition_id].to_i)
      if @currentconditions.count>0
        @currentconditions.destroy_all
  	    result = { success: true,
  	  	  info: 'Condition removed.',
  	  	  data: {} }
        render json: result
      else
        result = { success: false,
  	  	  info: 'Condition not found.',
  	  	  data: {} }
        render json: result, status: :unprocessable_entity 
      end
    else
   	  result = { success: false,
  	  	info: 'Sequence not found.',
  	  	data: {} }
      render json: result, status: :unprocessable_entity   
    end
  end

  api :POST, '/api/v1/custom_activity_forms/:id/add_kpi_to_sequence', 'Add a condition to a sequence'
  param :id, :number, required: true, desc: 'Activity ID to modify'
  param :custom_activity_sequence_id, :number, required: true, desc: 'Step/Sequence number to add KPI to' 
  param :kpi_id, :number, required: true, desc: 'ID of KPI that will be affected' 
  param :sequence_id_value_dependent_on, :number, required: true, desc: 'Step/Sequence number the KPI is dependent on' 
  param :operation, String, required: true, desc: 'Operatation that will be used' 
  param :operationValue, String, required: true, desc: 'Value that will be applied to operation' 
  def add_kpi_to_sequence
    @currentform=CustomActivityForm.find(params[:id])
    @currentseq=@currentform.custom_activity_sequences.where('id=?',params[:sequence_id].to_i)
    @kpi=@currentseq.first.custom_activity_kpi_operations.create(:custom_activity_sequence_id=>params[:custom_activity_sequence_id],:sequence_id_value_dependent_on=>params[:sequence_id_value_dependent],:kpi_id=>params[:kpi_id],:operation=>params[:operation],:operationValue=>params[:operationValue])
	render json: @kpi
  end

  api :POST, '/api/v1/custom_activity_forms/:id/remove_kpi_from_sequence', 'Remove a KPI from a sequence'
  param :id, :number, required: true, desc: 'Activity ID to modify'
  param :sequence_id, :number, required: true, desc: 'ID of Step/Sequence number to remove KPI from' 
  param :kpi_operation_id, :number, required: true, desc: 'ID of KPI to remove' 
  description <<-EOS
  	Example submission:
	{
	"sequence_id":"10",
	"kpi_operation_id":"8"
	}
	EOS
  def remove_kpi_from_sequence
    @currentform=CustomActivityForm.find(params[:id])
    @currentseq=@currentform.custom_activity_sequences.where('id=?',params[:sequence_id].to_i)
    if @currentseq.count>0
      @currentkpis=@currentseq.first.custom_activity_kpi_operations.where('id=?',params[:kpi_operation_id].to_i)
      if @currentkpis.count>0
        @currentkpis.destroy_all
  	    result = { success: true,
  	  	  info: 'KPI removed.',
  	  	  data: {} }
        render json: result
      else
        result = { success: false,
  	  	  info: 'KPI not found.',
  	  	  data: {} }
        render json: result, status: :unprocessable_entity 
      end
    else
   	  result = { success: false,
  	  	info: 'Sequence not found.',
  	  	data: {} }
      render json: result, status: :unprocessable_entity   
    end
  end

  def get_activity_form_fields
  	render json: get_form_fields(params[:id])
  end
  
  def get_activity_conditions
	@conditionout=get_nested_conditionals(params[:id])

	render json: @conditionout
				
	
  	#render json: @currentform.custom_activity_conditions
  end
  
  def get_sequences_with_names
  	sequencelist=[]
	@currentform=CustomActivityForm.find(params[:id])
	@currentform.custom_activity_sequences.each do |s|
		if s.reference_id!=nil
			if s.context=='ACTIVITY'
				activity=CustomActivityForm.find(s.reference_id)
				outgoing=[]
				outgoing<<s.id
				outgoing<<activity.name
			else
				activity=FormField.find(s.reference_id)
				outgoing=[]
				outgoing<<s.id
				outgoing<<activity.name			
			end  
			sequencelist<<outgoing
		end
	end
	render json: sequencelist
  end
  
  def get_form_field_type
  	render json: FormField.where('id=?',params['ffid']).first.type
  end
  
  def get_sequence_type
  	seq=CustomActivitySequence.where('id=?',params['seqid']).first
  	if seq=='ACTIVITY'
  		render json: 'ACTIVITY'
  	else
  		render json: FormField.where('id=?',seq.reference_id).first.type
  	end
  end

  def get_sequence_options
  	seq=CustomActivitySequence.where('id=?',params['seqid']).first
  	render json: FormFieldOption.where('form_field_id=?',seq.reference_id) 
  end
  
  def get_form_field_options
  	render json: FormFieldOption.where('form_field_id=?',params['ffid'])    
  end
  
  def delete_form_field_option
  	FormFieldOption.destroy(params['foid'].to_i)
  	render json: "deleted"
  end
  
  protected
  
  def permitted_params
    params.permit(custom_activity_form: [:name, :company_id,:description,:allowMultipleEntries,:showInQuickActions])[:custom_activity_form]    
  end
  
  def skip_default_validation
    true
  end
  
  def get_form_fields(id)
  		activity=CustomActivityForm.find(id)
		form_fields_array=[]
		@sequences=activity.custom_activity_sequences.order(:sequence)
		
		@sequences.each do |s|
			if s.context=='ACTIVITY'
				form_fields_array << get_form_fields( s.reference_id)
			else
				form_fields_array << FormField.find(s.reference_id)
			end
		end
		form_fields_array.flatten			
	end
	
	def get_nested_conditionals(id)
 		@currentform=CustomActivityForm.find(id)
 		conditionarray=[]		
		conditionarray<<@currentform.custom_activity_conditions 		
		@currentform.custom_activity_sequences.where(:context=>'ACTIVITY').each do |seq|
			if seq.reference_id!=nil
				@causes=@currentform.custom_activity_conditions.where(:custom_activity_sequence_id=>seq.id)
				@affecthese=CustomActivityForm.find(seq.reference_id).custom_activity_sequences
				@causes.each do |cause|
					@affecthese.each do |aft|
						@condclone=cause.dup
						@condclone.custom_activity_sequence_id=aft.id
						conditionarray<< @condclone
					end
				end
				
			end
			conditionarray << get_nested_conditionals(seq.reference_id)
		end
		
		conditionarray.flatten
		
 	end
end
