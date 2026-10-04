class AddLoginToTeamMembers < ActiveRecord::Migration[7.1]
  def change
    add_column :team_members, :email, :string
    add_column :team_members, :password_digest, :string
    add_index :team_members, :email, unique: true
    add_reference :request_updates, :team_member, foreign_key: true
  end
end
