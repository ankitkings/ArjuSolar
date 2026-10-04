# Arju Solars — full Rails project

Public site (Home, About, Services, Projects, Our Team, Contact) + admin panel.
Stack: Ruby 3.1+, Rails 7.1, SQLite, Propshaft (no Node/JS build needed).

## Run locally
```bash
bundle install
bin/rails db:prepare db:seed      # on Windows: ruby bin/rails db:prepare db:seed
bin/rails server                  # http://localhost:3000
```
Admin: http://localhost:3000/admin/login — default `admin@arjusolars.com` / `ChangeMe123!`
Set your own before seeding: `ADMIN_EMAIL=you@x.com ADMIN_PASSWORD='Strong!Pass1' bin/rails db:seed`
(If the admin already exists, change the password in `bin/rails console`: `AdminUser.first.update(password: "new")`.)

## Features
1. **Visitor tracking** – IP, browser, OS, device, page, referrer for each public page view (bots skipped) → Admin › Visitors.
2. **Team sections** – Installation Team, Contact Person, Daily Servicing, Cashier Department → public /team, managed in Admin › Team.
3. **Admin panel** – Dashboard, Users (customers), Requests with status, progress %, assignee and a timeline of notes.
Contact form saves requests to the database (honeypot spam trap + validation). Admin login is throttled (10 tries / 10 min / IP).

## Production
```bash
export SECRET_KEY_BASE=$(bin/rails secret)
RAILS_ENV=production bin/rails db:prepare db:seed assets:precompile
RAILS_ENV=production bin/rails server -b 0.0.0.0
```
- Serve behind HTTPS (set `FORCE_SSL=false` only if your proxy doesn't forward the https header).
- SQLite lives in `storage/`; use a persistent disk (`DATABASE_PATH`) or switch to PostgreSQL (`gem "pg"`, change `config/database.yml`) on hosts with ephemeral disks (Render, Heroku).
- Replace the TODO text in About / Services / Projects with your existing content.
- IP addresses are personal data: keep the footer notice, consider a privacy page.
