class AssetsUploadWorker
  include Sidekiq::Worker
  sidekiq_options queue: :upload, retry: 3

  def perform(asset_id, asset_class = 'AttachedAsset')
    klass ||= asset_class.constantize
    asset = klass.find(asset_id)
    if asset.processed? && asset.status_changed?
      asset.processed!
      asset.direct_upload_url = nil
      asset.delete_queued_process
      return
    end
    return if asset.processed? && asset.status_changed?
    asset.transfer_and_cleanup
  end
end
