# Turns a reporter payload into a catalog identity (vendor / line / machine / SKU) and component parts.
# Every rule about what a device IS lives here, server-side, so fixing a rule fixes every client.
class Probe
  VENDORS = {
    /\Alenovo/i => "Lenovo", /\Adell/i => "Dell", /\A(hp|hewlett)/i => "HP", /\Aasus/i => "ASUS",
    /\Aframework/i => "Framework", /\Amicro-star|\Amsi\b/i => "MSI", /\Aapple/i => "Apple",
    /\Aacer/i => "Acer", /\Asamsung/i => "Samsung", /\Amicrosoft/i => "Microsoft", /\Aqemu/i => "QEMU",
    /\Agigabyte/i => "Gigabyte", /\Atuxedo/i => "TUXEDO", /\Asystem76/i => "System76", /\Ahuawei/i => "Huawei"
  }.freeze

  # USB vendors that make fingerprint readers (same list as Omarchy's omarchy-hw-fingerprint, MIT).
  FINGERPRINT_VENDORS = %w[27c6 138a 06cb 08ff 1c7a 147e 10a5].freeze

  attr_reader :payload

  def initialize(payload) = @payload = payload.deep_stringify_keys

  def dmi = payload.fetch("dmi", {})
  def known?(s) = DmiAlias.normalize(s).present?

  def vendor_name
    raw = [ dmi["sys_vendor"], dmi["board_vendor"] ].find { known?(_1) } || "Unknown"
    VENDORS.find { |re, _| raw.match?(re) }&.last || raw.split(/[\s,]/).first.to_s.capitalize
  end

  def lenovo? = vendor_name == "Lenovo"
  def board_only? = !known?(lenovo? ? dmi["product_version"] : dmi["product_name"])

  # Lenovo puts the marketing name in product_version and the machine type in product_name.
  def model_name
    name = if board_only? then "#{dmi["board_name"]} (board)"
    elsif lenovo? then dmi["product_version"]
    else dmi["product_name"]
    end
    name.to_s.sub(/\A#{Regexp.escape(vendor_name)}\s+/i, "").squish.presence || "Unknown machine"
  end

  def line_name
    family = dmi["product_family"].to_s.squish
    known?(family) && !family.casecmp?(model_name) && family.length < model_name.length ? family : model_name.split.first
  end

  def sku_code
    code = lenovo? ? dmi["product_name"].to_s[0, 4] : dmi["product_sku"]
    (known?(code) ? code : model_name).to_s.squish
  end

  def alias_raw = [ dmi["sys_vendor"], dmi["product_name"], dmi["product_version"], dmi["product_sku"], dmi["board_name"] ].join(" ")

  # [{ kind:, key:, name: }] — only the kinds predictions use.
  def parts
    (devices.filter_map { device_part(_1) } + [ cpu_part, firmware_part ].compact).uniq { _1[:key] }
  end

  private
    def devices = Array(payload["devices"]).select { _1.is_a?(Hash) }
    def hex(v) = v.to_s.downcase[/\A[0-9a-f]{4}\z/]

    def device_part(d)
      vendor, device = hex(d["vendor"]), hex(d["device"])
      return unless vendor && device
      kind = case d["bus"]
      when "pci" then { "03" => "gpu", "0280" => "wifi" }.find { |prefix, _| d["class"].to_s.start_with?(prefix) }&.last
      when "usb" then usb_kind(vendor, d["classes"].to_s.split)
      when "hda" then "audio_codec" unless d["name"].to_s.match?(/hdmi|displayport/i) || %w[8086 1002 10de].include?(vendor)
      when "input" then "touchpad" if d["kind"] == "touchpad"
      end
      kind && { kind:, key: "#{d["bus"]}:#{vendor}:#{device}", name: d["name"].presence || d["product"].presence || "#{d["bus"]} #{vendor}:#{device}" }
    end

    def usb_kind(vendor, classes)
      return "bluetooth" if classes.include?("e0")
      return "webcam" if classes.include?("0e")
      "fingerprint" if FINGERPRINT_VENDORS.include?(vendor)
    end

    # ponytail: family-model is the microarchitecture on x86; aarch64 falls back to the name.
    def cpu_part
      cpu = payload.fetch("cpu", {})
      vendor = cpu["vendor"].to_s.downcase.sub(/\A(genuine|authentic)/, "").presence
      key = vendor && cpu["family"].present? ? "cpu:#{vendor}-#{cpu["family"]}-#{cpu["model"]}" : "cpu:#{cpu["name"].to_s.parameterize}"
      { kind: "cpu", key:, name: cpu["name"].presence || key } unless key == "cpu:"
    end

    def firmware_part = { kind: "firmware", key: "fw:#{vendor_name.parameterize}", name: "#{vendor_name} firmware" }
end
