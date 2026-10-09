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
    # unless Rails.env.production?
      m.email = "#{name.parameterize}@arjusolars.com"
      m.password = "Team@12"
    # end
  end
end

# ---------------------------------------------------------------
# Team chat: the shared "Everyone" group with a welcome message
# ---------------------------------------------------------------
everyone = Chat.everyone
everyone.add_member(AdminUser.first)
TeamMember.where(active: true).where.not(password_digest: nil).find_each { |m| everyone.add_member(m) }
if everyone.messages.none?
  everyone.messages.create!(sender: AdminUser.first, body: "Welcome to the team chat! Use this group for everyone, or start a personal or group chat from the list on the left.")
end

# ---------------------------------------------------------------
# System catalog (the installation team picks from this list)
# Prices are examples - change them in Admin > Systems.
# ---------------------------------------------------------------
[
  ["1 kW Starter",     1,  2,  "Waaree 540W",           "Luminous 1kW",  60_000],
  ["2 kW Home",        2,  4,  "Adani Solar 540W",      "Growatt 2kW",   120_000],
  ["3 kW Home",        3,  6,  "Waaree 540W",           "Luminous 3kW",  180_000],
  ["5 kW Home Plus",   5,  10, "Tata Power Solar 540W", "Sungrow 5kW",   300_000],
  ["10 kW Commercial", 10, 19, "Tata Power Solar 540W", "Sungrow 10kW",  550_000],
  ["20 kW Commercial", 20, 38, "Adani Solar 540W",      "Sungrow 20kW",  1_050_000]
].each do |name, kw, panels, brand, inverter, price|
  pkg = SolarPackage.find_or_create_by!(name: name) do |p|
    p.capacity_kw = kw
    p.panel_count = panels
    p.panel_brand = brand
    p.inverter_model = inverter
    p.price = price
  end
  pkg.update!(price: price) if pkg.price.nil?
end

# ---------------------------------------------------------------
# Parts price list: every part has its own price (used for custom quotes)
# Prices are examples - change them in Admin > Parts.
# ---------------------------------------------------------------
[
  # category, name, unit, price per unit, capacity per unit (kW)
  ["panel",      "Waaree 540W Mono PERC panel",             "piece", 9_800,   0.54],
  ["panel",      "Adani Solar 540W Mono panel",             "piece", 9_500,   0.54],
  ["panel",      "Tata Power Solar 540W panel",             "piece", 10_200,  0.54],
  ["panel",      "Vikram Solar 400W panel",                 "piece", 7_600,   0.40],
  ["inverter",   "Luminous 1kW inverter",                   "piece", 18_000,  1],
  ["inverter",   "Growatt 2kW inverter",                    "piece", 32_000,  2],
  ["inverter",   "Luminous 3kW inverter",                   "piece", 45_000,  3],
  ["inverter",   "Sungrow 5kW inverter",                    "piece", 72_000,  5],
  ["inverter",   "Sungrow 10kW inverter",                   "piece", 135_000, 10],
  ["inverter",   "Sungrow 20kW inverter",                   "piece", 240_000, 20],
  ["mounting",   "GI mounting structure (per kW)",          "kW",    6_000,   nil],
  ["mounting",   "Elevated structure for terrace (per kW)", "kW",    9_000,   nil],
  ["cables",     "DC + AC cables and connectors (per kW)",  "kW",    3_500,   nil],
  ["protection", "ACDB / DCDB protection boxes",            "set",   6_500,   nil],
  ["protection", "Earthing and lightning arrestor kit",     "set",   5_500,   nil],
  ["monitoring", "Wi-Fi monitoring device",                 "piece", 3_500,   nil],
  ["labour",     "Installation and commissioning (per kW)", "kW",    5_000,   nil],
  ["labour",     "Net-metering and documentation",          "job",   8_000,   nil],
  ["labour",     "Transport and handling",                  "job",   4_000,   nil]
].each do |category, name, unit, price, capacity|
  CatalogItem.find_or_create_by!(category: category, name: name) do |c|
    c.unit = unit
    c.unit_price = price
    c.capacity_kw = capacity
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
      ["pending",       0,   "Request received from website."],
      ["contacted",     10,  "Called the client; client is thinking it over."],
      ["site_visit",    30,  "Client agreed. Sent to the site visitor."],
      ["quote_sent",    50,  "Site visit done, quotation shared on WhatsApp."],
      ["installation",  75,  "Quote accepted. Installation in progress."],
      ["payment",       85,  "Installation done. Payment to be collected by the cashier."],
      ["commissioning", 95,  "Payment received in full. Panels to be started and final touch given."],
      ["completed",     100, "Panels started, final touch done. Project completed."]
    ]

    customers = [
      # name, phone, email, message, final status, days ago
      ["Amit Sharma",    "+91 98270 45612", "amit.sharma@example.com", "Need a 3kW rooftop system for my house in Vijay Nagar.",       "completed",     40],
      ["Priya Verma",    "+91 94250 22871", "priya.verma@example.com", "Interested in solar for my shop. Please share subsidy details.", "commissioning", 36],
      ["Rajesh Patel",   "+91 99810 33490", nil,                       "Want a 5kW system for our small factory.",                        "payment",       33],
      ["Sneha Joshi",    "+91 97540 66128", "sneha.j@example.com",     "Looking for rooftop solar with subsidy assistance.",              "installation",  28],
      ["Vikram Singh",   "+91 98930 77215", nil,                       "Commercial installation for our warehouse, around 20kW.",         "installation",  24],
      ["Meena Gupta",    "+91 93000 51984", "meena.gupta@example.com", "Please send a quotation for a 2kW home system.",                  "quote_sent",    20],
      ["Rohit Malviya",  "+91 98260 90433", nil,                       "Need quotation for 4kW. House has a flat terrace.",               "quote_sent",    16],
      ["Kavita Rathore", "+91 96440 12876", "kavita.r@example.com",    "Can you visit our school building for a site survey?",            "site_visit",    12],
      ["Sandeep Tiwari", "+91 98270 88301", nil,                       "Call me about solar water pump + panels for my farm.",            "contacted",     8],
      ["Anjali Dubey",   "+91 99770 14562", "anjali.dubey@example.com","I am interested in solar installation. Please contact me.",      "pending",       5],
      ["Harish Chouhan", "+91 94251 70998", nil,                       "What is the cost for a 3kW on-grid system?",                      "pending",       3],
      ["Farhan Ali",     "+91 98931 20456", "farhan.ali@example.com",  "Wanted solar but postponing due to renovation.",                  "cancelled",     22],
      ["Amit Sharma",    "+91 98270 45612", "amit.sharma@example.com", "Need yearly maintenance (AMC) for my installed system.",           "contacted",     2]
    ]

    addresses = ["12 Shreeji Apartments, Vijay Nagar, Indore 452010", "45 Palasia Main Road, Palasia, Indore", "7 Bhawarkua Square, Bhawarkua, Indore",
                 "Plot 9, Rau Industrial Area, Rau, Indore", "B-21 Saket Nagar, Saket, Indore", "33 Sudama Nagar, Sudama Nagar, Indore"]
    quoted = { "Amit Sharma" => "3 kW Home", "Priya Verma" => "2 kW Home", "Rajesh Patel" => "5 kW Home Plus",
               "Sneha Joshi" => "3 kW Home", "Vikram Singh" => "20 kW Commercial", "Meena Gupta" => "2 kW Home",
               "Rohit Malviya" => "5 kW Home Plus" }
    # payment plan for the three requests that already reached the payment stage
    pay_plan = { "Amit Sharma" => :two_receipts, "Priya Verma" => :two_receipts, "Rajesh Patel" => :partial }

    customers.each do |name, phone, email, message, final_status, days_ago|
      created   = now - days_ago.days - rng.rand(0..8).hours
      final_idx = steps.index { |s| s[0] == final_status } || 1
      path = final_status == "cancelled" ? steps[0..1] + [["cancelled", 0, "Client not agreed. Deal cancelled."]] : steps[0..final_idx]

      final  = path.last[0]
      dept   = RequestWorkflow::DEPARTMENT[final] || (final == "completed" ? "daily_servicing" : "contact_person")
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
        address: addresses.sample(random: rng),
        ip_address: "49.36.#{rng.rand(1..254)}.#{rng.rand(1..254)}",
        status: final, team_member: member,
        created_at: created, updated_at: last_time
      )
      req.update_columns(final_touch_due_on: Date.current) if final == "commissioning"

      path.each_with_index do |(st, prog, note), k|
        req.updates.create!(
          status: st, progress: (k == path.size - 1 ? req.progress : prog), note: note,
          admin_user: (k.zero? ? nil : admin),
          created_at: times[k], updated_at: times[k]
        )
      end

      # quotes for every request that reached the quote stage (Priya got a discount)
      if %w[quote_sent installation payment commissioning completed].include?(final)
        if name == "Rohit Malviya"
          custom = req.quotes.build(
            system_name: "Custom 4.32 kW system", discount: 0, valid_until: times[3].to_date + 15, status: "sent",
            team_member: TeamMember.where(department: "site_visitor").order(:id).first, created_at: times[3], updated_at: times[3]
          )
          [["Waaree 540W Mono PERC panel", 8], ["Sungrow 5kW inverter", 1], ["GI mounting structure (per kW)", 4.32],
           ["DC + AC cables and connectors (per kW)", 4.32], ["ACDB / DCDB protection boxes", 1],
           ["Earthing and lightning arrestor kit", 1], ["Installation and commissioning (per kW)", 4.32],
           ["Net-metering and documentation", 1]].each_with_index do |(part, qty), i|
            custom.quote_items.build(catalog_item: CatalogItem.find_by!(name: part), quantity: qty, position: i)
          end
          custom.save!
        else
        req.quotes.create!(
          solar_package: SolarPackage.find_by!(name: quoted.fetch(name, "3 kW Home")),
          discount: (name == "Priya Verma" ? 5_000 : 0), valid_until: times[3].to_date + 15,
          status: (final == "quote_sent" ? "sent" : "accepted"),
          team_member: TeamMember.where(department: "site_visitor").order(:id).first,
          created_at: times[3], updated_at: times[3]
        )
        end
      end

      # installed system + payment (demo installations have no photos, so they are not on the website)
      if %w[payment commissioning completed].include?(final)
        inst = Installation.create!(
          service_request: req, installed_on: last_time.to_date,
          solar_package: SolarPackage.find_by!(name: quoted.fetch(name)), site_address: req.address,
          public_location: Installation.guess_location(req.address), skip_photo_validation: true
        )
        inst.schedule_maintenance!
        cashier = (req.team_member if final == "payment") || TeamMember.where(department: "cashier").order(:id).offset(rng.rand(0..1)).first
        pay     = Payment.create!(service_request: req, team_member: cashier, amount_due: req.agreed_amount_for(inst))
        day     = [last_time.to_date + 1, Date.current].min
        case pay_plan.fetch(name)
        when :two_receipts
          pay.collect!(amount: (pay.amount_due * 0.5).round, mode: "cash", reference: "Advance", by: cashier, received_on: day)
          pay.collect!(amount: pay.balance, mode: "upi", reference: "UPI-#{rng.rand(100_000..999_999)}", by: cashier, received_on: [day + 2, Date.current].min)
        when :partial
          pay.collect!(amount: (pay.amount_due * 0.4).round, mode: "bank_transfer", reference: "NEFT-#{rng.rand(100_000..999_999)}", by: cashier, received_on: day)
        end
      end
    end

    # visits whose date has already arrived are handed to the servicing team
    MaintenanceVisit.assign_due!
    MaintenanceVisit.where(status: "assigned").order(:due_on).first&.finish!("Panels cleaned, inverter readings normal.")
    puts "Demo: #{ServiceRequest.count} requests, #{Installation.count} installations, #{MaintenanceVisit.count} maintenance visits, " \
         "#{Quote.count} quotes, #{CatalogItem.count} parts, #{Payment.count} payments, #{Receipt.count} receipts"
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
