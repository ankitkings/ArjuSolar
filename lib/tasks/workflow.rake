namespace :maintenance do
  desc "Assign maintenance visits that are due today to the Daily Servicing team (run daily from cron)"
  task assign_due: :environment do
    puts "Assigned #{MaintenanceVisit.assign_due!} maintenance visit(s)"
  end
end

namespace :requests do
  desc "Re-run automatic assignment for all open requests (use after adding new departments or members)"
  task reassign: :environment do
    n = 0
    ServiceRequest.where(status: RequestWorkflow::ACTIVE_STATUSES).find_each do |r|
      r.reassign_for_stage!
      n += 1
    end
    puts "Checked #{n} open request(s)"
  end
end
