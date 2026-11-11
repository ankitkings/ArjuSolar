module Admin
  # Admin > Holidays: the calendar of days off for the whole team
  class HolidaysController < BaseController
    MAX_DAYS = 31

    def index
      @month = parse_month(params[:month])
      @holidays = Holiday.where(date: @month..@month.end_of_month).index_by(&:date)
      @year_list = Holiday.where(date: Date.new(@month.year, 1, 1)..Date.new(@month.year, 12, 31)).order(:date).to_a
    end

    # one day, or several days in a row (a festival of three days, for example)
    def create
      attrs = params.require(:holiday).permit(:name, :kind, :note)
      from = parse_date(params.dig(:holiday, :from_date))
      to = parse_date(params.dig(:holiday, :to_date)) || from
      return redirect_back_to_calendar(from, alert: "Choose the date of the holiday.") unless from
      return redirect_back_to_calendar(from, alert: "The last day cannot be before the first day.") if to < from
      return redirect_back_to_calendar(from, alert: "A holiday can be at most #{MAX_DAYS} days in a row.") if (to - from).to_i >= MAX_DAYS

      added = 0
      problems = []
      (from..to).each do |day|
        holiday = Holiday.new(attrs.to_h.merge(date: day))
        if holiday.save then added += 1
        elsif !Holiday.on?(day) then problems << holiday.errors.full_messages.to_sentence
        end
      end
      if problems.any?
        redirect_back_to_calendar(from, alert: problems.uniq.to_sentence)
      else
        skipped = (to - from).to_i + 1 - added
        message = "#{attrs[:name]}: #{added} #{'day'.pluralize(added)} added."
        message += " #{skipped} #{'day'.pluralize(skipped)} already had a holiday." if skipped.positive?
        redirect_back_to_calendar(from, notice: message)
      end
    end

    def destroy
      holiday = Holiday.find(params[:id])
      holiday.destroy
      redirect_back_to_calendar(holiday.date, notice: "#{holiday.name} (#{holiday.date.strftime('%d %b %Y')}) removed.")
    end

    def national
      year = params[:year].to_i
      year = Date.current.year unless year.between?(2000, 2100)
      added = Holiday.add_national_days(year)
      redirect_to admin_holidays_path(month: "#{year}-#{Date.current.year == year ? format('%02d', Date.current.month) : '01'}"),
                  notice: added.zero? ? "The national holidays of #{year} were already in the calendar." : "#{added} national #{'holiday'.pluralize(added)} added for #{year}."
    end

    private

    def redirect_back_to_calendar(date, **flash)
      redirect_to admin_holidays_path(month: (date || Date.current).strftime("%Y-%m")), **flash
    end

    def parse_month(value)
      Date.strptime(value.to_s, "%Y-%m")
    rescue ArgumentError
      Date.current.beginning_of_month
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
