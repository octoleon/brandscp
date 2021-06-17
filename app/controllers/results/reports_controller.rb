class Results::ReportsController < InheritedResources::Base
  respond_to :js, only: [:new, :create, :edit, :update, :share_form, :show]
  respond_to :json, only: [:filters]
  before_action :set_report_params, only: [:show, :rows, :preview]

  load_and_authorize_resource except: [:index]

  before_action :autorize_results, only: [:index]

  helper_method :return_path

  # This helper provide the methods to activate/deactivate the resource
  include DeactivableController

  def index
    @reports = current_company.reports.active.accessible_by_user(current_company_user).order('reports.name ASC')
    @data_extracts = current_company.data_extracts.active.order('data_extracts.name ASC')
  end

  def preview
    @report = Report.new(permitted_params.merge(company_id: current_company.id, name: resource.name))
    @report.page = 1
  end

  def build
  end

  def show
    if request.format.csv?
      @export = ListExport.create(
        controller: self.class.name,
        url_options: url_options,
        params: filter_params,
        export_format: :csv,
        company_user: current_company_user)

      if @export.new?
        @export.queue!
      end
      render action: :new_export, formats: [:js]
    end
  end

  def rows
    render layout: false
  end

  def share_form
    @sharing_collection = ActiveRecord::Base.connection.unprepared_statement do
      ActiveRecord::Base.connection.select_all("
        #{current_company.company_users.select('company_users.id, users.first_name || \' \' || users.last_name as name, \'company_user\' as type').active.joins(:user).to_sql}
        UNION ALL
        #{current_company.roles.select('roles.id, roles.name, \'role\' as type').active.to_sql}
        UNION ALL
        #{current_company.teams.select('teams.id, teams.name, \'team\' as type').active.to_sql}
        ORDER BY name ASC
      ").map { |r| [r['name'], "#{r['type']}:#{r['id']}", { class: r['type'] }] }
    end
  end

  def filters
    respond_to do |format|
      format.json { render json: { filters: resource.filters.map(&:as_filter) } }
    end
  end

  private

  def export_list(export, path)
    File.open(path, 'w') do |f|
      f.write render_to_string(
        text: resource.to_csv { |total, i| export.update_column(:progress, (i * 100 / total).round) }
      )
    end
  end

  def build_resource_params
    [permitted_params || {}]
  end

  def permitted_params
    allowed =
      if params[:id].present?
        if can?(:edit, resource)
          [:name, :description,
           { rows: [:field, :label, :aggregate] },
           { columns: [:field, :label] },
           { values: [:field, :label, :aggregate, :precision, :display] },
           { filters: [:field, :label] }]
        else
          []
        end
      else
        [:name, :description]
      end
    allowed += [:sharing, { sharing_selections: [] }] if params[:id].present? && can?(:share, resource)
    params.permit(report: allowed)[:report] || {}
  end

  def filter_params
    params.permit(:id, *resource.filters.map(&:allowed_filter_params))
  end

  def export_file_name
    sanitize_filename resource.name
  end

  def sanitize_filename(filename)
    filename.strip.tap do |name|
      # NOTE: File.basename doesn't work right with Windows paths on Unix
      # get only the filename, not the whole path
      name.gsub!(/^.*(\\|\/)/, '')

      # Strip out the non-ascii character
      name.gsub!(/[^0-9A-Za-z.\-]/, '_')
    end
  end

  def set_report_params
    resource.page = (params[:page].try(:to_i) || 1)
    resource.filter_params = filter_params unless action_name == 'show'
  end

  def return_path
    if action_name == 'build'
      resource_path
    else
      collection_path
    end
  end

  def autorize_results
    authorize! :access, :results
  end
end
