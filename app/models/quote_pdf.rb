require "prawn"
require "prawn/table"

# Builds the quotation as a PDF file (same content as the on-screen quote).
# Built-in PDF fonts are used, so text is converted to Latin characters and the rupee sign is written "Rs.".
class QuotePdf
  def self.render(quote) = new(quote).render

  def initialize(quote)
    @q = quote
    @req = quote.service_request
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: 40,
                              info: { Title: "Quotation #{@q.number}", Author: "Arju Solars" })
    header(pdf)
    parties(pdf)
    body(pdf)
    footer(pdf)
    pdf.render
  end

  private

  # keep only characters the built-in PDF font can print (e.g. Hindi letters become "?")
  def t(text)
    text.to_s.encode("Windows-1252", undef: :replace, invalid: :replace, replace: "?").encode("UTF-8")
  end

  def rs(amount) = t(Rupees.display(amount).sub("₹", "Rs. "))
  def qty(number) = format("%g", number)

  def header(pdf)
    top = pdf.cursor
    pdf.text "Arju Solars", size: 20, style: :bold
    pdf.fill_color "555555"
    pdf.text "Indore, Madhya Pradesh, India", size: 9
    pdf.text "+91 7049465926", size: 9
    pdf.fill_color "000000"
    pdf.text_box "QUOTATION\n#{@q.number}\nDate: #{@q.created_at.strftime('%d %b %Y')}\nValid until: #{@q.valid_until.strftime('%d %b %Y')}",
                 at: [pdf.bounds.right - 220, top], width: 220, align: :right, size: 10
    pdf.move_down 16
    pdf.stroke_color "CCCCCC"
    pdf.stroke_horizontal_rule
    pdf.move_down 12
  end

  def parties(pdf)
    pdf.text "Prepared for: #{t(@req.name)}  |  #{t(@req.phone)}", size: 10
    pdf.text "Site address: #{t(@req.address)}", size: 10 if @req.address.present?
    pdf.move_down 12
  end

  def body(pdf)
    items = @q.quote_items.to_a
    if items.any?
      pdf.text "System: #{t(@q.system_name)} - #{format('%g', @q.capacity_kw.to_f)} kW, #{@q.panel_count} panels, inverter #{t(@q.inverter_model)}", size: 10
      pdf.move_down 8
      data = [["Part", "Quantity", "Unit price", "Amount"]]
      items.each { |i| data << [t(i.description), "#{qty(i.quantity)} #{t(i.unit)}", rs(i.unit_price), rs(i.line_total)] }
      data << [{ content: "Subtotal", colspan: 3, align: :right }, rs(@q.list_price)]
      data << [{ content: "Discount", colspan: 3, align: :right }, "- #{rs(@q.discount)}"] if @q.discount.positive?
      data << [{ content: "Total", colspan: 3, align: :right }, rs(@q.total)]
      widths = [235, 80, 100, 100]
    else
      data = [["System", "Amount"]]
      data << ["#{t(@q.system_name)} - #{format('%g', @q.capacity_kw.to_f)} kW solar system\n" \
               "#{@q.panel_count} panels, #{t(@q.panel_brand)}, inverter #{t(@q.inverter_model)}", rs(@q.list_price)]
      data << ["Discount", "- #{rs(@q.discount)}"] if @q.discount.positive?
      data << ["Total", rs(@q.total)]
      widths = [415, 100]
    end

    last_row = data.length - 1
    last_col = widths.length - 1
    pdf.table(data, header: true, column_widths: widths) do
      cells.size = 9
      cells.padding = [6, 6]
      cells.borders = [:bottom]
      cells.border_color = "CCCCCC"
      row(0).font_style = :bold
      row(0).background_color = "EEEEEE"
      row(last_row).font_style = :bold
      columns(1..last_col).align = :right
    end
    pdf.move_down 14
  end

  def footer(pdf)
    pdf.text "Notes: #{t(@q.notes)}", size: 9 if @q.notes.present?
    pdf.text "Prepared by: #{t(@q.team_member&.name || 'Arju Solars')}#{' (Site Visitor)' if @q.team_member}", size: 9
    pdf.move_down 8
    pdf.fill_color "777777"
    pdf.text "This quotation is valid until #{@q.valid_until.strftime('%d %b %Y')}. This is a computer-generated document.", size: 8
  end
end
