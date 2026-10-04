# ---------------------------------------------------------------
# Admin login
# ---------------------------------------------------------------
AdminUser.find_or_create_by!(email: ENV.fetch("ADMIN_EMAIL", "admin@arjusolars.com")) do |a|
  a.password = ENV.fetch("ADMIN_PASSWORD", "ChangeMe123!")
end

# ---------------------------------------------------------------
# Team: one or more people per department
# (outside production they also get a login: <name>@arjusolars.com / Team@12345)
# ---------------------------------------------------------------
[
  ["Ankit Parmar",  "contact_person",  "+91 7049465926",  "First point of contact for quotes and callbacks."],
  ["Neha Sharma",   "contact_person",  "+91 98260 11105", "Customer support and subsidy assistance."],
  ["Vikas Rawat",   "site_visitor",    "+91 98260 11201", "Visits the site, measures the roof and sends the quote."],
  ["Karan Solanki", "site_visitor",    "+91 98260 11202", "Site survey and quotation specialist."],
  ["Rakesh Verma",  "installation",    "+91 98260 11101", "Lead installer with 8 years of rooftop experience."],
  ["Sunil Patel",   "installation",    "+91 98260 11102", "Electrical and panel mounting specialist."],
  ["Imran Khan",    "installation",    "+91 98260 11103", "Inverter and wiring technician."],
  ["Mohan Yadav",   "daily_servicing", "+91 98260 11106", "Regular servicing, cleaning and performance checks."],
  ["Deepak Joshi",  "daily_servicing", nil,               "AMC visits and system monitoring."],
  ["Pooja Mehta",   "cashier",         "+91 98260 11108", "Payments, invoices and receipts."],
  ["Ravi Soni",     "cashier",         nil,               "Subsidy paperwork and billing."]
].each do |name, dept, phone, bio|
  TeamMember.find_or_create_by!(name: name, department: dept) do |m|
    m.phone = phone
    m.bio = bio
    unless Rails.env.production?
      m.email = "#{name.parameterize}@arjusolars.com"
      m.password = "Team@12345"
    end
  end
end

# ---------------------------------------------------------------
# DEMO DATA (requests, installations, maintenance, payments, visitors)
# Skipped in production or with SEED_DEMO=false. Runs only if tables are empty.
# ---------------------------------------------------------------
if !Rails.env.production? && ENV["SEED_DEMO"] != "false"
  rng   = Random.new(42)
  admin = AdminUser.first
  now   = Time.current

  if ServiceRequest.none?
    steps = [
      ["pending",      0,   "Request received from website."],
      ["contacted",    10,  "Called the client; client is thinking it over."],
      ["site_visit",   30,  "Client agreed. Sent to the site visitor."],
      ["quote_sent",   50,  "Site visit done, quotation shared on WhatsApp."],
      ["installation", 75,  "Quote accepted. Installation in progress."],
      ["completed",    100, "Installation completed and handed over."]
    ]

    customers = [
      # name, phone, email, message, final status, days ago
      ["Amit Sharma",    "+91 98270 45612", "amit.sharma@example.com", "Need a 3kW rooftop system for my house in Vijay Nagar.",       "completed",    40],
      ["Priya Verma",    "+91 94250 22871", "priya.verma@example.com", "Interested in solar for my shop. Please share subsidy details.", "completed",    36],
      ["Rajesh Patel",   "+91 99810 33490", nil,                       "Want a 5kW system for our small factory.",                        "completed",    33],
      ["Sneha Joshi",    "+91 97540 66128", "sneha.j@example.com",     "Looking for rooftop solar with subsidy assistance.",              "installation", 28],
      ["Vikram Singh",   "+91 98930 77215", nil,                       "Commercial installation for our warehouse, around 20kW.",         "installation", 24],
      ["Meena Gupta",    "+91 93000 51984", "meena.gupta@example.com", "Please send a quotation for a 2kW home system.",                  "quote_sent",   20],
      ["Rohit Malviya",  "+91 98260 90433", nil,                       "Need quotation for 4kW. House has a flat terrace.",               "quote_sent",   16],
      ["Kavita Rathore", "+91 96440 12876", "kavita.r@example.com",    "Can you visit our school building for a site survey?",            "site_visit",   12],
      ["Sandeep Tiwari", "+91 98270 88301", nil,                       "Call me about solar water pump + panels for my farm.",            "contacted",    8],
      ["Anjali Dubey",   "+91 99770 14562", "anjali.dubey@example.com","I am interested in solar installation. Please contact me.",      "pending",      5],
      ["Harish Chouhan", "+91 94251 70998", nil,                       "What is the cost for a 3kW on-grid system?",                      "pending",      3],
      ["Farhan Ali",     "+91 98931 20456", "farhan.ali@example.com",  "Wanted solar but postponing due to renovation.",                  "cancelled",    22],
      ["Amit Sharma",    "+91 98270 45612", "amit.sharma@example.com", "Need yearly maintenance (AMC) for my installed system.",           "contacted",    2]
    ]

    # installed system data + payment for the three completed requests (in order)
    installs = [[3, 6, "Waaree 500W", "Luminous 3kW"], [2, 4, "Adani Solar 540W", "Growatt 2kW"], [5, 10, "Tata Power Solar 540W", "Sungrow 5kW"]]
    pays     = [["received", 185_000], ["received", 128_000], ["pending", nil]]

    customers.each do |name, phone, email, message, final_status, days_ago|
      created   = now - days_ago.days - rng.rand(0..8).hours
      final_idx = steps.index { |s| s[0] == final_status } || 1
      path = final_status == "cancelled" ? steps[0..1] + [["cancelled", 10, "Client not agreed. Request cancelled."]] : steps[0..final_idx]

      final  = path.last[0]
      dept   = RequestWorkflow::DEPARTMENT[final] || (final == "completed" ? "installation" : "contact_person")
      # pending requests are left unassigned on purpose: the model auto-assigns a contact person
      member = final == "pending" ? nil : TeamMember.where(department: dept).order(:id).offset(rng.rand(0..1)).first

      last_time = created
      times = path.each_index.map do |k|
        t = created + (k * rng.rand(1..3)).days + rng.rand(1..6).hours
        t = [t, now - 1.minute].min
        last_time = [last_time, t].max
        t
      end

      req = ServiceRequest.create!(
        name: name, phone: phone, email: email, message: message,
        ip_address: "49.36.#{rng.rand(1..254)}.#{rng.rand(1..254)}",
        status: final, team_member: member, progress: (final == "cancelled" ? 10 : 0),
        created_at: created, updated_at: last_time
      )

      path.each_with_index do |(st, prog, note), k|
        req.updates.create!(
          status: st, progress: (k == path.size - 1 ? req.progress : prog), note: note,
          admin_user: (k.zero? ? nil : admin),
          created_at: times[k], updated_at: times[k]
        )
      end

      if final == "completed"
        kw, panels, brand, inverter = installs.shift
        inst = Installation.create!(
          service_request: req, installed_on: last_time.to_date, capacity_kw: kw, panel_count: panels,
          panel_brand: brand, inverter_model: inverter, site_address: "Indore, Madhya Pradesh"
        )
        inst.schedule_maintenance!
        status, amount = pays.shift
        Payment.create!(
          service_request: req, team_member: TeamMember.where(department: "cashier").order(:id).offset(rng.rand(0..1)).first,
          status: status, amount: amount, received_on: (last_time.to_date if status == "received")
        )
      end
    end

    # visits whose date has already arrived are handed to the servicing team
    MaintenanceVisit.assign_due!
    MaintenanceVisit.where(status: "assigned").order(:due_on).first&.finish!("Panels cleaned, inverter readings normal.")
    puts "Demo: #{ServiceRequest.count} requests, #{Installation.count} installations, " \
         "#{MaintenanceVisit.count} maintenance visits, #{Payment.count} payments"
  end

  # ----- Website visitors -----
  if Visit.none?
    uas = [
      "Mozilla/5.0 (Linux; Android 13; SM-A346E) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 12; Redmi Note 11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15"
    ]
    prefixes  = %w[49.36 106.208 157.45 103.211 117.202 27.60 152.58]
    visitors  = Array.new(45) { { ip: "#{prefixes.sample(random: rng)}.#{rng.rand(1..254)}.#{rng.rand(1..254)}", ua: uas.sample(random: rng) } }
    entry     = %w[/ / / / /services /projects /about /contact]
    pages     = %w[/ /about /services /projects /team /contact]
    referrers = [nil, nil, nil, "https://www.google.com/", "https://www.google.com/", "https://www.facebook.com/", "https://l.instagram.com/", "https://wa.me/"]

    rows = []
    200.times do
      v     = visitors.sample(random: rng)
      t     = now - ((rng.rand**1.6) * 30 * 24 * 3600).seconds
      path  = entry.sample(random: rng)
      ref   = referrers.sample(random: rng)
      rng.rand(1..4).times do
        rows << {
          ip_address: v[:ip], user_agent: v[:ua],
          browser: Visit.browser_for(v[:ua]), os: Visit.os_for(v[:ua]),
          device: v[:ua].match?(/Mobile|Android|iPhone/i) ? "Mobile" : "Desktop",
          path: path, referrer: ref, visited_at: [t, now - 1.minute].min
        }
        ref  = "http://localhost:3000#{path}"
        path = pages.sample(random: rng)
        t   += rng.rand(20..180).seconds
      end
    end
    Visit.insert_all(rows)
    puts "Demo: created #{Visit.count} visits from #{Visit.distinct.count(:ip_address)} visitors"
  end
end
