class AddAdminAssignment < ActiveRecord::Migration[7.1]
  def change
    # a request can be with the Admin (instead of a teammate), e.g. while it waits for a PM Surya Ghar step
    add_column :service_requests, :assigned_to_admin, :boolean, null: false, default: false

    reversible do |dir|
      dir.up do
        execute "UPDATE service_requests SET assigned_to_admin = TRUE, team_member_id = NULL " \
                "WHERE installation_status IN ('waiting_for_approval', 'waiting_for_net_meter')"
      end
    end
  end
end
