class CustomActivityFormResultHeader < ActiveRecord::Base
  has_many :custom_activity_form_result_details
  belongs_to :user
  belongs_to :event
  belongs_to :custom_activity_form
  include SolrSearchable

  
  searchable do

    integer :user_id
    integer :event_id
    integer :id
    integer :custom_activity_form_id

  end
   
end
