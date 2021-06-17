# == Schema Information
#
# Table name: brand_portfolios
#
#  id            :integer          not null, primary key
#  name          :string(255)
#  active        :boolean          default("true")
#  company_id    :integer
#  created_by_id :integer
#  updated_by_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  description   :text
#

class BrandPortfolio < ActiveRecord::Base
  # Created_by_id and updated_by_id fields
  track_who_does_it

  scoped_to_company

  has_paper_trail

  validates :name, presence: true, uniqueness: { scope: :company_id }
  validates :company_id, presence: true

  # Campaigns-Brands Portfolios relationship
  has_and_belongs_to_many :campaigns, order: 'name ASC', conditions: { aasm_state: 'active' }

  has_and_belongs_to_many :brands, order: 'name ASC', conditions: { brands: { active: true } }

  scope :active, -> { where(active: true) }

  scope :accessible_by_user, ->(user) { in_company(user.company_id) }

  searchable do
    integer :id

    text :name, stored: true

    string :name
    string :status

    boolean :active

    integer :company_id

    integer :brand_ids, multiple: true do
      brands.map(&:id)
    end
    string :brands, multiple: true, references: Brand do
      brands.map { |t| t.id.to_s + '||' + t.name }
    end
  end

  def activate!
    update_attribute :active, true
  end

  def deactivate!
    update_attribute :active, false
  end

  def status
    self.active? ? 'Active' : 'Inactive'
  end

  class << self
    # We are calling this method do_search to avoid conflicts with other gems like meta_search used by ActiveAdmin
    def do_search(params, include_facets = false)
      solr_search do

        with(:company_id, params[:company_id])
        with(:brand_ids, params[:brand]) if params.key?(:brand) && params[:brand].present?
        with(:status, params[:status]) if params.key?(:status) && params[:status].present?
        with(:id, params[:brand_portfolio]) if params.key?(:brand_portfolio) && params[:brand_portfolio].present?

        if include_facets
          facet :brands
          facet :status
        end

        order_by(params[:sorting] || :name, params[:sorting_dir] || :asc)
        paginate page: (params[:page] || 1), per_page: (params[:per_page] || 30)
      end
    end

    def searchable_params
      [brand: [], brand_portfolio: [], status: []]
    end

    def report_fields
      {
        name: { title: 'Name' }
      }
    end
  end

  def filter_subitems
    brands.pluck('brands.id, brands.name, \'brand\'')
 end
end
