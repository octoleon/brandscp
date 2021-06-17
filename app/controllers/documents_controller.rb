# Documents Controller class
#
# This class handle the requests for the Documents
#
class DocumentsController < InheritedResources::Base
  respond_to :js, only: [:create, :destroy]

  belongs_to :event, :campaign, polymorphic: true

  include DeactivableController
  include PhotosHelper

  defaults resource_class: AttachedAsset

  load_and_authorize_resource class: AttachedAsset, through: :parent

  skip_load_and_authorize_resource only: [:create]
  before_action :authorize_create, only: [:create]

  helper_method :describe_filters

  protected

  def build_resource_params
    [(permitted_params || {}).merge(asset_type: 'document')]
  end

  def permitted_params
    params.permit(attached_asset: [:direct_upload_url])[:attached_asset]
  end

  def authorize_create
    if parent.is_a?(Campaign)
      authorize! :add_document, parent
    else
      authorize! :create_document, parent
    end
  end
end
