class CustomActivityForm < ActiveRecord::Base
  has_many :custom_activity_sequences
  has_many :campaign_custom_activity_forms
  has_many :campagn_custom_activity_forms
  has_many :campaigns, :through => :campaign_custom_activity_forms
  has_many :custom_activity_conditions, :through => :custom_activity_sequences
  has_many :events, :through => :campaigns
  has_many :custom_activity_form_result_headers
  has_many :custom_activity_form_result_details, :through => :custom_activity_form_result_headers
  belongs_to :company
  
  include SolrSearchable
  
  searchable do
    text :name, stored: true
    string :name
    integer :company_id
    integer :id
  end
end
