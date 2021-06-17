class Api::V1::CampaignSummaryReportController < Api::V1::FilteredController
  api :GET, '/api/v1/campaign_summary_report/autocomplete', 'Return a list of results grouped by categories'
  param :q, String, required: true, desc: 'The search term'
  description <<-EOS
  Returns a list of results matching the searched term grouped in the following categories
  * *Brands*: Includes brands and brand portfolios
  * *Areas*: Includes areas
  * *Peope*: Includes users and teams
  * *Event Status*: Includes Submitted, Late, Due, Approved, Rejected
  EOS
  def autocomplete
    authorize! :index, Event
    autocomplete = Autocomplete.new('campaign_summary_report', current_company_user, params)
    render json: autocomplete.search
  end
end
