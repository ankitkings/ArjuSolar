# Draws a UPI payment QR code. Needs the "rqrcode" gem (bundle add rqrcode); without it the page still
# shows the payment link and nothing else breaks.
module UpiQr
  def self.available?
    return true if defined?(RQRCode::QRCode)
    require "rqrcode"
    true
  rescue LoadError
    false
  end

  def self.svg(text)
    return nil unless available?
    RQRCode::QRCode.new(text, level: :m).as_svg(module_size: 5, standalone: true, use_path: true, viewbox: true,
                                                shape_rendering: "crispEdges", color: "000")
  end
end
