class CustomActivityFormsController < FilteredController
	def new
		@value=CustomActivityForm.all

	end
	
	def show
		@value=CustomActivityForm.all
		@currentsequences=get_sequences_with_names(resource.id)

	end
	
	def viewer
		@questions=get_sequences_with_names(params[:custom_activity_form_id])	
		@currentcaf=CustomActivityForm.find(params[:custom_activity_form_id])	
	end
	
	def eventviewer
		@questions=get_sequences_with_names(params['id'])	
		@currentcaf=CustomActivityForm.find(params['id'])	
		@event_id=params['event_id']
		#render json: params
	end
	
	def save_event_activity
		@cafrh=CustomActivityFormResultHeader.create(:event_id=> params['event_id'], :user_id=> current_user.id, :custom_activity_form_id=>params[:id])
		params.each do |key,value|
			if key.to_i>0
				@cafrh.custom_activity_form_result_details.create(:form_field_id => key.to_i, :result => value)
			end
		end
		
		render json: @cafrh.id
	end	
	
	def edit
	
	end

	
	private

  def get_activity_form_fields(id)
	@formfields= get_form_fields(id)
	formfieldsandoptions=[]
	@formfields.each do |f| 
		hash={}
		hash[:field]=f 
		hash[:options] = f.options
		formfieldsandoptions << hash
	end
	formfieldsandoptions
  end
  	
  		
  def get_form_fields(id)
  		activity=CustomActivityForm.find(id)
		form_fields_array=[]
		@sequences=activity.custom_activity_sequences.order(:sequence)
		
		@sequences.each do |s|
			if s.reference_id!=nil
				if s.context=='ACTIVITY'
					form_fields_array << get_form_fields( s.reference_id)
				else
					form_fields_array << FormField.find(s.reference_id)
				end
			end
		end
		form_fields_array.flatten			
	end

###Original version of get_sequences_with_names.  This reused the activity sequence id when displaying the underlying form fields.
#   def get_sequences_with_names(id)
#   	sequencelist = []
# 	@currentform = CustomActivityForm.find(id)
# 	@currentform.custom_activity_sequences.order(:sequence).each do |s|
# 		if s.reference_id != nil
# 			if s.context=='ACTIVITY'
# 
# 				activities=get_form_fields(s.reference_id)
# 				activities.each do |activity|
# 					outgoing={}
# 					outgoing['sequence']=s.id
# 					outgoing['formfield']=activity
# 					outgoing['options']=activity.options
# 					sequencelist<<outgoing unless outgoing.nil?
# 				end
# 			else
# 				activity=FormField.find(s.reference_id)
# 				outgoing={}
# 				outgoing['sequence']= s.id
# 				outgoing['formfield'] =activity	
# 				outgoing['options']=activity.options
# 				sequencelist<<outgoing unless outgoing.nil?
# 			end  
# 		end
# 	end
# 	sequencelist
#   end	
  
  def get_sequences_with_names(id)
  	sequencelist = []
	@currentform = CustomActivityForm.find(id)
	@currentform.custom_activity_sequences.order(:sequence).each do |s|
		if s.reference_id != nil
			if s.context=='ACTIVITY'

				activities=get_sequences_with_names(s.reference_id)
				sequencelist<<activities unless activities.nil?
			else
				activity=FormField.find(s.reference_id)
				outgoing={}
				outgoing['sequence']= s.id
				outgoing['formfield'] =activity	
				outgoing['options']=activity.options
				sequencelist<<outgoing unless outgoing.nil?
			end  
		end
	end
	sequencelist.flatten
  end	
  
end
