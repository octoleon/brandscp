class CustomActivitySequence < ActiveRecord::Base
  belongs_to :custom_activity_form
  has_many :custom_activity_kpi_operations
  has_many :custom_activity_conditions
	
  include SolrSearchable

  
  searchable do
    integer :custom_activity_form_id
    string :context
    integer :sequence
    integer :reference_id
  end
end
