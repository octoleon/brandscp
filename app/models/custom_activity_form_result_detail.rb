class CustomActivityFormResultDetail < ActiveRecord::Base
  has_many :form_fields
  belongs_to :custom_activity_form_result_header
  include SolrSearchable

  
  searchable do
    text :result, stored: true

    string :result
    integer :form_field_id
    integer :id
    integer :custom_activity_form_result_header_id

  end
   
end
