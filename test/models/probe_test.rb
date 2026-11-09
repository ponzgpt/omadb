require "test_helper"

class ProbeTest < ActiveSupport::TestCase
  def probe(dmi, devices = []) = Probe.new("dmi" => dmi, "devices" => devices, "cpu" => {})

  test "Lenovo: name from product_version, SKU from machine type" do
    p = probe("sys_vendor" => "LENOVO", "product_name" => "21MLCTO1WW", "product_version" => "ThinkPad T14 Gen 5")
    assert_equal [ "Lenovo", "ThinkPad T14 Gen 5", "21ML", "ThinkPad" ], [ p.vendor_name, p.model_name, p.sku_code, p.line_name ]
  end

  test "custom desktops are identified by their board" do
    p = probe("sys_vendor" => "System manufacturer", "product_name" => "System Product Name",
      "board_vendor" => "ASUSTeK COMPUTER INC.", "board_name" => "ROG STRIX B650-A GAMING WIFI")
    assert_equal "ASUS", p.vendor_name
    assert_equal "ROG STRIX B650-A GAMING WIFI (board)", p.model_name
  end

  test "vendor prefix is stripped and HDMI codecs are not audio parts" do
    p = probe({ "sys_vendor" => "HP", "product_name" => "HP EliteBook 840 G10", "product_sku" => "8A1B2C" },
      [ { "bus" => "hda", "vendor" => "8086", "device" => "281d", "name" => "Intel HDMI" } ])
    assert_equal "EliteBook 840 G10", p.model_name
    assert_equal "8A1B2C", p.sku_code
    assert_equal %w[firmware], p.parts.map { _1[:kind] }
  end
end
