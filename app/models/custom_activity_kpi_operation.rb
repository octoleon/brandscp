class CustomActivityKpiOperation < ActiveRecord::Base
  belongs_to :custom_activity_sequence
  has_many :kpis
	
  include SolrSearchable
  
  searchable do
    integer :custom_activity_kpi_operation_id
    integer :custom_activity_sequence_id
    integer :sequence_id_value_dependent_on
    integer :kpi_id
  end		

end
