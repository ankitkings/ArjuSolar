module ApplicationHelper
  def inr(amount)
    Rupees.display(amount)
  end

  # Progress bar; a cancelled deal is drawn fully red (and shows 0%)
  def progress_bar(record, big: false)
    classes = ["bar", ("big" if big), ("cancelled" if record.status == "cancelled")].compact.join(" ")
    content_tag(:div, content_tag(:i, "", style: "width:#{record.progress}%"), class: classes)
  end

  # The picture the admin uploaded for a system, or a default solar photo
  def package_image_src(package)
    if package.image.attached? && package.image.blob.persisted?
      url_for(package.image)
    else
      SiteImages::DEFAULT_SYSTEM
    end
  end

  # <option>s for "Assigned to": grouped by department, every person with their number of
  # active tasks, least busy first. Example: "Neha Sharma (Contact Person) (3 active tasks)"
  def team_member_options(service_request)
    counts = TeamMember.active_task_counts
    members = TeamMember.where(active: true).or(TeamMember.where(id: service_request.team_member_id)).to_a.group_by(&:department)
    groups = TeamMember::DEPARTMENTS.filter_map do |key, label|
      list = members[key]
      next if list.blank?
      options = list.sort_by { |m| [counts[m.id], m.name] }.map do |m|
        n = counts[m.id]
        ["#{m.name} (#{label}) (#{n} active #{n == 1 ? 'task' : 'tasks'})", m.id]
      end
      [label, options]
    end
    grouped_options_for_select(groups, service_request.team_member_id)
  end
end
