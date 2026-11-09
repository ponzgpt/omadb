require "test_helper"
require "open3"

# Runs the real reporter against a fake /sys + /proc tree, then files its payload through the API.
class ReporterTest < ActionDispatch::IntegrationTest
  SERIAL = "PF4XYZ123SERIAL"

  setup { @root = Dir.mktmpdir("omadb-sys") }
  teardown { FileUtils.rm_rf(@root) }

  def put(path, content)
    FileUtils.mkdir_p(File.dirname(File.join(@root, path)))
    File.write(File.join(@root, path), content)
  end

  def fake_thinkpad(machine_id: "0123456789abcdef0123456789abcdef", live: false)
    { "sys_vendor" => "LENOVO", "product_name" => "21MLCTO1WW", "product_version" => "ThinkPad T14 Gen 5",
      "product_family" => "ThinkPad T14 Gen 5", "product_sku" => "LENOVO_MT_21ML_BU_Think_FM_ThinkPad T14 Gen 5",
      "board_vendor" => "LENOVO", "board_name" => "21MLCTO1WW", "product_serial" => SERIAL, "board_serial" => SERIAL }
      .each { |k, v| put("sys/class/dmi/id/#{k}", "#{v}\n") }
    put("etc/machine-id", machine_id)
    put("proc/cpuinfo", "vendor_id\t: GenuineIntel\ncpu family\t: 6\nmodel\t\t: 170\nmodel name\t: Intel(R) Core(TM) Ultra 7 155U\n")
    { "0000:00:02.0" => %w[0x8086 0x7d45 0x030000], "0000:00:14.3" => %w[0x8086 0x7e40 0x028000] }.each do |slot, (v, d, c)|
      put("sys/bus/pci/devices/#{slot}/vendor", v); put("sys/bus/pci/devices/#{slot}/device", d); put("sys/bus/pci/devices/#{slot}/class", c)
    end
    put("sys/bus/usb/devices/3-10/idVendor", "8087"); put("sys/bus/usb/devices/3-10/idProduct", "0033")
    put("sys/bus/usb/devices/3-10/bDeviceClass", "e0"); put("sys/bus/usb/devices/3-10/3-10:1.0/bInterfaceClass", "e0")
    put("sys/bus/usb/devices/3-10/serial", SERIAL)
    put("proc/asound/card0/codec#0", "Codec: Realtek ALC257\nVendor Id: 0x10ec0257\n")
    put("proc/asound/card0/codec#2", "Codec: Intel Meteorlake HDMI\nVendor Id: 0x8086281d\n")
    put("proc/bus/input/devices", "I: Bus=0018 Vendor=06cb Product=ce7e Version=0100\nN: Name=\"SYNA8018:00 06CB:CE7E Touchpad\"\n\n")
    FileUtils.mkdir_p(File.join(@root, "run/archiso")) if live
  end

  def dry_run
    out, err, status = Open3.capture3({ "OMADB_SYSROOT" => @root }, "bash", Rails.root.join("reporter/report.sh").to_s, "--dry-run")
    assert status.success?, err
    out
  end

  def submit(payload, features: Feature::CORE.to_h { [ _1, "works" ] })
    post reports_path, params: payload.merge("features" => features), as: :json
    response.parsed_body
  end

  test "the reporter collects parts and never sends serials" do
    fake_thinkpad
    raw = dry_run
    refute_includes raw, SERIAL
    payload = JSON.parse(raw)
    assert_match(/\A[0-9a-f]{32}\z/, payload["machine_hash"])
    refute_includes raw, "0123456789abcdef0123456789abcdef", "machine-id must be hashed"
    assert_equal "installed", payload["source"]
    keys = Probe.new(payload).parts.map { _1[:key] }
    assert_equal %w[pci:8086:7d45 pci:8086:7e40 usb:8087:0033 hda:10ec:0257 input:06cb:ce7e cpu:intel-6-170 fw:lenovo].sort, keys.sort
  end

  test "a first report verifies the SKU; a re-run replaces, a second machine adds" do
    fake_thinkpad
    payload = JSON.parse(dry_run)

    body = submit(payload)
    assert_response :created
    assert body["first_on_sku"]
    assert_equal "platinum", body["tier"]
    assert_equal "Lenovo ThinkPad T14 Gen 5", body["machine"]

    submit(payload, features: { "wifi" => "broken" })
    assert_equal 1, Report.count, "same machine + version replaces its report"

    other = payload.merge("machine_hash" => "f" * 32)
    refute submit(other)["first_on_sku"]
    assert_equal 2, Report.count
    assert_equal 1, Sku.count

    get machine_path(Machine.sole)
    assert_response :success
    assert_select "h1", "Lenovo ThinkPad T14 Gen 5"
  end

  test "the live ISO path files a borked install" do
    fake_thinkpad(live: true)
    payload = JSON.parse(dry_run)
    assert_equal "live_iso", payload["source"]
    assert_equal "borked", submit(payload, features: { "install_boot" => "broken" })["tier"]
  end

  test "notes wait for moderation; garbage is refused" do
    fake_thinkpad
    submit(JSON.parse(dry_run).merge("note" => "needs the bios update"))
    assert_equal "pending", Report.sole.notes_status
    post reports_path, params: { machine_hash: "nope", source: "installed" }, as: :json
    assert_response :unprocessable_content
  end

  test "the script is served as plain text" do
    get reporter_path
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_includes response.body, "Nothing is sent without your \"y\""
  end
end
