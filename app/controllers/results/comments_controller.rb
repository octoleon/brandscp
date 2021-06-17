class Results::CommentsController < FilteredController
  defaults resource_class: ::Event
  respond_to :csv, only: :index

  helper_method :return_path

  private

  def collection_to_csv
    (CSV.generate do |csv|
      csv << ['CAMPAIGN NAME', 'VENUE NAME', 'ADDRESS', 'COUNTRY', 'EVENT START DATE', 'EVENT END DATE',
              'CREATED AT', 'CREATED BY', 'LAST MODIFIED', 'MODIFIED BY', 'COMMENT']
      each_collection_item do |event|
        event.comments.each do |comment|
          comment = Csv::CommentPresenter.new(comment, nil)
          csv << [event.campaign_name, event.current_place.try(:name), event.place_address, event.current_place.try(:country), event.start_date,
                  event.end_date, comment.created_at, comment.created_by, comment.last_modified, comment.modified_by, comment.content]
        end
      end
    end).encode('WINDOWS-1252', undef: :replace, replace: '')
  end

  def search_params
    @search_params || (super.tap do |p|
      p[:search_permission] = :index_results
      p[:search_permission_class] = Comment
      p[:with_comments_only] = true unless p.key?(:user) && !p[:user].empty?
    end)
  end

  def authorize_actions
    authorize! :index_results, Comment
  end

  def return_path
    results_reports_path
  end

  def permitted_search_params
    Event.searchable_params
  end
end
