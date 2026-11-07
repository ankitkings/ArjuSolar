# The texts, details and choices that make up the public website. The admin changes them in Admin > Website.
class SiteSetting < ApplicationRecord
  SECTIONS = { "show_stats" => "Numbers strip under the banner", "show_why" => "“Why choose us” cards", "show_services" => "Our services",
               "show_systems" => "Ready-to-install systems", "show_how" => "How it works", "show_projects" => "Recent installations",
               "show_faq" => "Questions (FAQ)" }.freeze

  DEFAULTS = {
    company_name: "Arju Solars",
    tagline: "Powering your future",
    hero_eyebrow: "☀️ Solar installation, service & maintenance · Indore",
    hero_title: "Powering *your future* with the sun",
    hero_subtitle: "Affordable, clean and efficient solar for homes and businesses. We plan it, install it, help you claim the government subsidy and look after it for years.",
    about_title: "Clean energy that is affordable and looked after",
    about_text: "Arju Solars provides affordable, clean and efficient solar energy solutions for homes and businesses across Central India, from our base in Indore, Madhya Pradesh.\n\nWe believe going solar should be simple: an honest quotation, a tidy installation and a team that is still there years later when you need service.",
    footer_text: "Powering Central India with clean energy: installation, service and maintenance for homes and businesses.",
    office_hours: "Mon – Sat, 9:00 AM – 6:00 PM",
    meta_description: "Arju Solars installs rooftop solar for homes and businesses in Indore and Central India: free site visit, subsidy help, installation, service and maintenance."
  }.freeze

  DEFAULT_CONTACTS = [["phone", "Call us", "+91 7049465926"], ["whatsapp", "WhatsApp", "+91 7049465926"],
                      ["email", "E-mail", "ankitparmar5035582@gmail.com"], ["address", "Office", "Indore, Madhya Pradesh, India"]].freeze
  DEFAULT_FAQS = [
    ["Can I get a government subsidy?", "Home (residential) systems can qualify for the PM Surya Ghar: Muft Bijli Yojana subsidy. We help you with the documents and the application, and your quotation shows the subsidy."],
    ["What happens after the installation?", "We start your system, give it the final touch and schedule maintenance checks. If something is wrong with your panels during the warranty, call us and we will send an engineer to check."],
    ["How can I pay?", "You can pay by cash, UPI, bank transfer, cheque or card, and you always get a numbered receipt."]
  ].freeze

  URL_FORMAT = %r{\Ahttps?://[^\s]+\z}i

  validates :company_name, presence: true, length: { maximum: 60 }
  validates :tagline, length: { maximum: 80 }
  validates :hero_eyebrow, length: { maximum: 120 }
  validates :hero_title, presence: true, length: { maximum: 120 }
  validates :hero_subtitle, :footer_text, :meta_description, length: { maximum: 600 }
  validates :about_title, length: { maximum: 140 }
  validates :about_text, length: { maximum: 4000 }
  validates :office_hours, length: { maximum: 100 }
  validates :facebook_url, :instagram_url, :youtube_url, :linkedin_url, format: { with: URL_FORMAT, message: "must start with http:// or https://" }, allow_blank: true

  before_validation do
    %i[facebook_url instagram_url youtube_url linkedin_url].each { |field| self[field] = self[field].to_s.strip.presence }
  end

  # the one and only row; on the very first use it is filled with today's website details
  def self.current
    first || begin
      setting = create!(DEFAULTS)
      DEFAULT_CONTACTS.each_with_index { |(kind, label, value), i| ContactEntry.create!(kind: kind, label: label, value: value, position: i) } if ContactEntry.none?
      DEFAULT_FAQS.each_with_index { |(question, answer), i| FaqItem.create!(question: question, answer: answer, position: i) } if FaqItem.none?
      setting
    end
  end

  def primary_phone = ContactEntry.active.listed.find_by(kind: "phone")&.value
  def socials = { "Facebook" => facebook_url, "Instagram" => instagram_url, "YouTube" => youtube_url, "LinkedIn" => linkedin_url }.compact_blank
end
