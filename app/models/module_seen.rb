# "N new" next to a menu item of the admin panel: how many things came in since the admin last opened that module.
class ModuleSeen < ApplicationRecord
  belongs_to :admin_user

  # menu module => how to count what is new since a moment
  COUNTERS = {
    "requests"    => ->(since) { ServiceRequest.where("created_at > ?", since).count },
    "users"       => ->(since) do   # a person who sends a request for the first time
      phones = ServiceRequest.where("created_at > ?", since).where.not(phone_key: [nil, ""]).distinct.pluck(:phone_key)
      phones.count { |key| !ServiceRequest.where(phone_key: key).where("created_at <= ?", since).exists? }
    end,
    "visitors"    => ->(since) { Visit.where("visited_at > ?", since).count },
    "payments"    => ->(since) { Receipt.where("created_at > ?", since).count },
    "maintenance" => ->(since) { MaintenanceVisit.where("created_at > ?", since).count },
    "systems"     => ->(since) { SolarPackage.where("created_at > ?", since).count },
    "parts"       => ->(since) { CatalogItem.where("created_at > ?", since).count },
    "subsidy"     => ->(since) { SubsidyApplication.where("created_at > ?", since).count },
    "clients"     => ->(since) { Customer.where("created_at > ?", since).count },
    "team"        => ->(since) { TeamMember.where("created_at > ?", since).count },
    "attendance"  => ->(since) { Attendance.where("created_at > ?", since).count },
    "salary"      => ->(since) { SalaryPayment.where("created_at > ?", since).count }
  }.freeze

  # the page whose opening counts as "seen" (the list page of the module)
  CONTROLLERS = {
    "service_requests" => "requests", "users" => "users", "visits" => "visitors", "payments" => "payments",
    "maintenance_visits" => "maintenance", "solar_packages" => "systems", "catalog_items" => "parts",
    "subsidy_applications" => "subsidy", "customers" => "clients", "team_members" => "team",
    "attendance" => "attendance", "salary_payments" => "salary"
  }.freeze

  # { "users" => 3, "maintenance" => 1, ... }. The first time, nothing counts as new.
  def self.counts_for(admin)
    seen = where(admin_user_id: admin.id).pluck(:module_key, :seen_at).to_h
    COUNTERS.to_h do |key, counter|
      since = seen[key] || begin
        record = find_or_create_by!(admin_user_id: admin.id, module_key: key) { |r| r.seen_at = Time.current }
        record.seen_at
      end
      [key, counter.call(since)]
    end
  end

  def self.mark_seen!(admin, key)
    record = find_or_initialize_by(admin_user_id: admin.id, module_key: key)
    record.seen_at = Time.current
    record.save!
  rescue ActiveRecord::RecordNotUnique
    where(admin_user_id: admin.id, module_key: key).update_all(seen_at: Time.current)
  end
end
