module TeamMembersHelper
  module InstanceMethods
    def delete_member
      if member
        user = member.dup
        if resource.users.destroy(member)
          users = user.id
        end
      elsif team
        team_users = team.user_ids
        if resource.teams.destroy(team)
          resource.solr_index
          assigned_users = resource.user_ids
          users = team_users - assigned_users
        end
      end
    end

    def new_member
      @staff = assignable_staff_members
    end

    def add_members
      @staff_changed = false
      params[:new_members].each do |item|
        type, id = item.split('_')
        if type == 'user'
          member =  company_users.find(id)
          unless resource.user_ids.include?(member.id)
            resource.update_attributes(user_ids: resource.user_ids + [member.id])
            @staff_changed = true
          end
        elsif type == 'team'
          unless resource.teams.where(id: id).first
            team = company_teams.find(id)
            resource.teams << team
            resource.solr_index
          end
        end
      end if params[:new_members].present?
    end

    def members
      render layout: false
    end

    def teams
      render layout: false
    end

    private

    def member
      @member = resource.users.find(params[:member_id])
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def resource_members
      @members ||= resource.users.includes(:user).order('users.first_name ASC, users.first_name ASC')
    end

    def team
      @team = resource.teams.find(params[:team_id]) if resource.respond_to?(:teams)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def company_users
      @company_users ||= CompanyUser.active.where(company_id: current_company).joins(:user, :role).where('users.invitation_accepted_at is not null')
    end

    def company_teams
      @company_teams ||= current_company.teams.active.order('teams.name ASC')
    end

    def assignable_teams
      @assignable_teams ||= if resource.is_a?(Team)
                              company_teams.where('0=1')
      else
        company_teams.with_active_users(current_company).where('teams.id not in (?)', resource.team_ids + [0])
        # @assignable_teams ||= company_teams.with_active_users(current_company).order('teams.name ASC').select do |team|
        #   !resource.team_ids.include?(team.id)
        # end
     end
    end

    def assignable_staff_members
      # When resource is a Campaign, user_ids should include memmberships from brand and brand portfolios
      ids =  resource.is_a?(Campaign) ? resource.staff_users.map(&:id) : resource.user_ids
      users = company_users.where(['company_users.id not in (?)', ids + [0]])
      ActiveRecord::Base.connection.unprepared_statement do
        ActiveRecord::Base.connection.select_all("
          #{users.select('company_users.id, users.first_name || \' \' || users.last_name AS name, roles.name as description, \'user\' as type').reorder(nil).to_sql}
          UNION ALL
          #{assignable_teams.select('teams.id, teams.name, teams.description, \'team\' as type').reorder(nil).to_sql}
          ORDER BY name
        ")
      end
    end
  end

  def self.extended(receiver)
    receiver.send(:include, InstanceMethods)
    receiver.send(:helper_method, :resource_members)
    receiver.send(:cache_sweeper, :notification_sweeper, only: [:add_members, :delete_member])
  end
end
