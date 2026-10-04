class Visit < ApplicationRecord
  BOT = /bot|crawl|spider|slurp|preview|monitor/i

  def self.log(request)
    ua = request.user_agent.to_s
    return if ua.blank? || ua.match?(BOT)
    create(
      ip_address: request.remote_ip, user_agent: ua.truncate(255),
      browser: browser_for(ua), os: os_for(ua), device: ua.match?(/Mobile|Android|iPhone/i) ? "Mobile" : "Desktop",
      path: request.path, referrer: request.referer.to_s.truncate(255).presence, visited_at: Time.current
    )
  rescue => e
    Rails.logger.warn("Visit log failed: #{e.message}")
  end

  def self.browser_for(ua)
    case ua
    when /Edg/ then "Edge"
    when /OPR|Opera/ then "Opera"
    when /Chrome/ then "Chrome"
    when /Firefox/ then "Firefox"
    when /Safari/ then "Safari"
    else "Other"
    end
  end

  def self.os_for(ua)
    case ua
    when /Android/ then "Android"
    when /iPhone|iPad|iOS/ then "iOS"
    when /Windows/ then "Windows"
    when /Mac OS/ then "macOS"
    when /Linux/ then "Linux"
    else "Other"
    end
  end
end
