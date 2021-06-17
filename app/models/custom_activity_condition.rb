class CustomActivityCondition < ActiveRecord::Base
  belongs_to :custom_activity_sequence

  include SolrSearchable
  
  searchable do
    integer :custom_activity_condition_id
    integer :sequence_id_dependent_on
    integer :sequence_id_value_dependent_on
  end	
end