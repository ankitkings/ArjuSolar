# Safe to run again: it only creates what is missing.
class CreateSiteContent < ActiveRecord::Migration[7.1]
  def up
    unless table_exists?(:site_settings)
      create_table :site_settings do |t|
        t.string :company_name, null: false, default: "Arju Solars"
        t.string :tagline
        t.string :hero_eyebrow
        t.string :hero_title
        t.text :hero_subtitle
        t.string :about_title
        t.text :about_text
        t.text :footer_text
        t.string :office_hours
        t.text :meta_description
        t.string :facebook_url
        t.string :instagram_url
        t.string :youtube_url
        t.string :linkedin_url
        # which parts of the home page are shown
        t.boolean :show_stats, null: false, default: true
        t.boolean :show_why, null: false, default: true
        t.boolean :show_services, null: false, default: true
        t.boolean :show_systems, null: false, default: true
        t.boolean :show_how, null: false, default: true
        t.boolean :show_projects, null: false, default: true
        t.boolean :show_faq, null: false, default: true
        t.timestamps
      end
    end

    unless table_exists?(:contact_entries)
      create_table :contact_entries do |t|
        t.string :kind, null: false          # phone / whatsapp / email / address
        t.string :label
        t.string :value, null: false
        t.integer :position, null: false, default: 0
        t.boolean :active, null: false, default: true
        t.timestamps
      end
    end

    unless table_exists?(:faq_items)
      create_table :faq_items do |t|
        t.string :question, null: false
        t.text :answer, null: false
        t.integer :position, null: false, default: 0
        t.boolean :active, null: false, default: true
        t.timestamps
      end
    end
  end

  def down
    drop_table :faq_items if table_exists?(:faq_items)
    drop_table :contact_entries if table_exists?(:contact_entries)
    drop_table :site_settings if table_exists?(:site_settings)
  end
end
