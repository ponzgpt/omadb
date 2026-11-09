require "test_helper"

class SkuTest < ActiveSupport::TestCase
  setup do
    line = Vendor.create!(name: "Lenovo", slug: "lenovo").model_lines.create!(name: "ThinkPad", slug: "thinkpad")
    @wifi = Component.create!(kind: "wifi", key: "pci:8086:272b", name: "Intel BE200")
    @parts = { "cpu" => "cpu:intel-lunarlake", "firmware" => "fw:lenovo", "gpu" => "pci:8086:64a0", "audio_codec" => "hda:10ec:0257" }
      .map { |kind, key| Component.create!(kind:, key:, name: key) } + [ @wifi ]
    @t14 = line.machines.create!(name: "ThinkPad T14 Gen 5", slug: "thinkpad-t14-gen-5").skus.create!(code: "21ML")
    @x1 = line.machines.create!(name: "ThinkPad X1 Carbon Gen 13", slug: "thinkpad-x1-carbon-gen-13").skus.create!(code: "21NS")
    @parts.each { @x1.sku_components.create!(component: _1, source: "catalog") }
  end

  def report!(sku, **statuses)
    sku.reports.create!(machine_hash: SecureRandom.hex, omarchy_version: "3.2.0", components: @parts).tap do |r|
      Feature::CORE.each { |f| r.feature_results.create!(feature: f, status: statuses.fetch(f.to_sym, "works")) }
    end
  end

  test "status layer moves from unverified to predicted to verified" do
    assert_equal "unverified", @x1.status_layer
    report!(@t14)
    assert_equal "predicted", @x1.reload.status_layer
    assert_equal Tier[:gold], @x1.prediction.tier
    report!(@x1)
    assert_equal "verified", @x1.reload.status_layer
    assert_equal Tier[:platinum], @x1.rating.tier
  end

  test "an out-of-tree fix rates bronze" do
    dkms = Fix.create!(slug: "wifi-dkms", title: "Build the DKMS driver", feature: "wifi", out_of_tree: true)
    r = report!(@t14)
    r.feature_results.find_by(feature: "wifi").update!(status: "works_after_fix", fix: dkms)
    assert_equal Tier[:bronze], @t14.rating.tier
  end

  test "latest version compares numerically, not as text" do
    @t14.reports.create!(machine_hash: "a" * 32, omarchy_version: "9.1")
    @t14.reports.create!(machine_hash: "b" * 32, omarchy_version: "10.0")
    assert_equal "10.0", Report.latest_version
  end
end
