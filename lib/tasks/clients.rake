namespace :clients do
  desc "Make client profiles for people who sent a request but have none yet (safe to run again)"
  task backfill: :environment do
    made, linked, left = Customer.backfill_from_requests!
    puts "#{made} client profiles made, #{linked} requests linked, #{left} requests left without a profile (no e-mail address)"
  end
end
