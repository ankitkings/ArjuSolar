class AddFinalStagesAndSitePhotos < ActiveRecord::Migration[7.1]
  def change
    add_column :service_requests, :final_touch_due_on, :date   # when Daily Servicing should start the panels
    add_column :installations, :public_location, :string      # area + city shown on the website
    add_column :installations, :show_on_website, :boolean, null: false, default: true

    # A cancelled deal now shows 0% (it used to keep the progress it had)
    reversible do |dir|
      dir.up { execute "UPDATE service_requests SET progress = 0 WHERE status = 'cancelled'" }
    end
  end
end
