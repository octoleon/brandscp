# Brands Controller class
#
# This class handle the requests for managing the Brands
#
class BrandsController < FilteredController
  actions :index, :new, :create, :edit, :update
  belongs_to :campaign, :brand_portfolio, optional: true
  respond_to :json, :xls, :pdf, only: [:index]
  respond_to :js, only: [:new, :create, :edit, :update]

  has_scope :not_in_portfolio

  # This helper provide the methods to activate/deactivate the resource
  include DeactivableController

  def create
    create! do |success, _|
      success.js do
        parent.brands << resource if parent? && parent
        render :create
      end
    end
  end

  def index
    respond_to do |format|
      format.html
      format.xls { super }
      format.pdf { super }
      format.json { render json: collection.map { |b| { id: b.id, name: b.name } } }
    end
  end

  protected

  def collection_to_csv
    CSV.generate do |csv|
      csv << ['NAME', 'ACTIVE STATE']
      each_collection_item do |brand|
        csv << [brand.name, brand.status]
      end
    end
  end

  def permitted_params
    params.permit(brand: [:name, :marques_list])[:brand]
  end

  def authorize_actions
    authorize! :index, resource_class
  end
end
