require 'rails_helper'

describe TeamsController, type: :controller do
  before(:each) do
    @user = sign_in_as_user
    @company = @user.current_company
    @company_user = @user.current_company_user
  end

  let(:team) { create(:team, company: @company) }

  describe "GET 'edit'" do
    it 'returns http success' do
      xhr :get, 'edit', id: team.to_param, format: :js
      expect(response).to be_success
    end
  end

  describe "GET 'index'" do
    it 'returns http success' do
      get 'index'
      expect(response).to be_success
    end

    it 'queue the job for export the list to CSV' do
      expect(ListExportWorker).to receive(:perform_async).with(kind_of(Numeric))
      expect do
        xhr :get, :index, format: :csv
      end.to change(ListExport, :count).by(1)
      export = ListExport.last
      expect(export.controller).to eql('TeamsController')
      expect(export.export_format).to eql('csv')
    end

    it 'queue the job for export the list to PDF' do
      expect(ListExportWorker).to receive(:perform_async).with(kind_of(Numeric))
      expect do
        xhr :get, :index, format: :pdf
      end.to change(ListExport, :count).by(1)
      export = ListExport.last
      expect(export.controller).to eql('TeamsController')
      expect(export.export_format).to eql('pdf')
    end
  end

  describe "GET 'new'" do
    it 'returns http success' do
      xhr :get, 'new', format: :js
      expect(response).to be_success
      expect(response).to render_template('new')
      expect(response).to render_template('_form')
    end
  end

  describe "GET 'items'" do
    it 'returns http success' do
      get 'items'
      expect(response).to be_success
    end
  end

  describe "GET 'show'" do
    it 'assigns the loads the correct objects and templates' do
      get 'show', id: team.id
      expect(assigns(:team)).to eq(team)
      expect(response).to render_template(:show)
    end
  end

  describe "POST 'create'" do
    it 'returns http success' do
      xhr :post, 'create', format: :js
      expect(response).to be_success
    end

    it 'should not render form_dialog if no errors' do
      expect do
        xhr :post, 'create', team: { name: 'Test Team', description: 'Test Team description' }, format: :js
      end.to change(Team, :count).by(1)
      expect(response).to be_success
      expect(response).to render_template(:create)
      expect(response).not_to render_template('_form_dialog')

      team = Team.last
      expect(team.name).to eq('Test Team')
      expect(team.description).to eq('Test Team description')
    end

    it 'should render the form_dialog template if errors' do
      expect do
        xhr :post, 'create', format: :js
      end.not_to change(Team, :count)
      expect(response).to render_template(:create)
      expect(response).to render_template('_form_dialog')
      expect(assigns(:team).errors.count).to be > 0
    end
  end

  describe "GET 'deactivate'" do

    it 'deactivates an active team' do
      team.update_attribute(:active, true)
      xhr :get, 'deactivate', id: team.to_param, format: :js
      expect(response).to be_success
      expect(team.reload.active?).to be_falsey
    end

    it 'activates an inactive team' do
      team.update_attribute(:active, false)
      xhr :get, 'activate', id: team.to_param, format: :js
      expect(response).to be_success
      expect(team.reload.active?).to be_truthy
    end
  end

  describe "PUT 'update'" do
    it 'must update the team attributes' do
      t = create(:team)
      put 'update', id: team.to_param, team: { name: 'Test Team', description: 'Test Team description' }
      expect(assigns(:team)).to eq(team)
      expect(response).to redirect_to(team_path(team))
      team.reload
      expect(team.name).to eq('Test Team')
      expect(team.description).to eq('Test Team description')
    end
  end

  describe "DELETE 'delete_member'" do
    it 'should remove the team member from the team' do
      team.users << @company_user
      expect do
        delete 'delete_member', id: team.id, member_id: @company_user.id, format: :js
        expect(response).to be_success
        expect(assigns(:team)).to eq(team)
        team.reload
      end.to change(team.users, :count).by(-1)
    end

    it "should not raise error if the user doesn't belongs to the team" do
      delete 'delete_member', id: team.id, member_id: @company_user.id, format: :js
      team.reload
      expect(response).to be_success
      expect(assigns(:team)).to eq(team)
    end
  end

  describe "GET 'new_member" do
    it 'correctly assign the team' do
      xhr :get, 'new_member', id: team.id, format: :js
      expect(response).to be_success
      expect(assigns(:team)).to eq(team)
      expect(assigns(:staff).to_a).to eq([{ 'id' => @company_user.id.to_s, 'name' => 'Test User', 'description' => 'Super Admin', 'type' => 'user' }])
    end

    it 'correctly assign the users' do
      users = create_list(:company_user, 3, company: @company, role_id: @company_user.role_id, active: true)
      users << @company_user # the current user should also appear on the list

      # Assign the users to other team
      other_team = create(:team, company: @company)
      users.each { |u| other_team.users << u }

      # Create some other users that should not be included
      create(:user, :invited, company: @company, role_id: @company_user.role_id) # invited user
      create(:company_user, company: @company, role_id: @company_user.role_id, active: false) # inactive user
      create(:company_user, company_id: @company.id + 1, role_id: @company_user.role_id, active: true) # user from other company
      xhr :get, 'new_member', id: team.id, format: :js
      expect(response).to be_success
      expect(assigns(:staff)).to match_array users.map { |u| { 'id' => u.id.to_s, 'name' => u.full_name, 'description' => u.role_name, 'type' => 'user' } }
    end

    it 'should not load the users that are already assigned ot the team' do
      another_user = create(:company_user, company_id: @company.id, role_id: @company_user.role_id)
      team.users << @company_user
      xhr :get, 'new_member', id: team.id, format: :js
      expect(response).to be_success
      expect(assigns(:team)).to eq(team)
      expect(assigns(:staff).to_a).to eq([{ 'id' => another_user.id.to_s, 'name' => 'Test User', 'description' => 'Super Admin', 'type' => 'user' }])
    end
  end

  describe "POST 'add_members" do
    it 'should assign the user to the team' do
      expect do
        xhr :post, 'add_members', id: team.id, new_members: ["user_#{@company_user.to_param}"], format: :js
        expect(response).to be_success
        expect(assigns(:team)).to eq(team)
        team.reload
      end.to change(team.users, :count).by(1)
      expect(team.users).to eq([@company_user])
    end

    it 'should not assign users to the team if they are already part of the team' do
      team.users << @company_user
      expect do
        xhr :post, 'add_members', id: team.id, new_members: ["user_#{@company_user.to_param}"], format: :js
        expect(response).to be_success
        expect(assigns(:team)).to eq(team)
        team.reload
      end.not_to change(team.users, :count)
    end
  end

  describe "GET 'list_export'", :search, :inline_jobs do
    it 'should return an empty book with the correct headers' do
      expect { xhr :get, 'index', format: :csv }.to change(ListExport, :count).by(1)
      expect(ListExport.last).to have_rows([
        ['NAME', 'DESCRIPTION', 'MEMBERS', 'ACTIVE STATE']
      ])
    end

    it 'should include the results' do
      create(:team, name: 'Costa Rica Team',
              description: 'El grupo de ticos', active: true, company: @company)
      Sunspot.commit

      expect { xhr :get, 'index', format: :csv }.to change(ListExport, :count).by(1)
      expect(ListExport.last).to have_rows([
        ['NAME', 'DESCRIPTION', 'MEMBERS', 'ACTIVE STATE'],
        ['Costa Rica Team', 'El grupo de ticos', '0', 'Active']
      ])
    end
  end
end
