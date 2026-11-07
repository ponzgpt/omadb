require "test_helper"

class RatingTest < ActiveSupport::TestCase
  WORKS = Feature::CORE.to_h { [ _1, "works" ] }

  def entry(version = "3.2", machine: "T14", components: {}, **statuses)
    Rating::Entry.new(version:, statuses: WORKS.merge(statuses.transform_keys(&:to_s)), components:, machine:)
  end

  def rating(*entries, latest: "3.2") = Rating.new(entries, latest_version: latest)

  test "n=1 still rates, with inadequate confidence" do
    r = rating(entry(audio: "works_after_fix"))
    assert_equal Tier[:gold], r.tier
    assert_equal "inadequate", r.confidence
    assert_equal 1, r.total_reports
  end

  test "confidence bands follow the report count" do
    assert_equal "good", rating(*Array.new(3) { entry }).confidence
    assert_equal "strong", rating(*Array.new(10) { entry }).confidence
  end

  test "one outlier cannot sink a machine (median, not worst)" do
    r = rating(entry, entry, entry, entry(wifi: "broken"))
    assert_equal Tier[:platinum], r.tier
    assert_equal Tier[:platinum], r.best_reported_tier
  end

  test "an even split is disputed and ties rate pessimistically" do
    r = rating(entry, entry(suspend: "broken"))
    assert r.disputed?
    assert_equal({ "works" => 1, "broken" => 1 }, r.disputes["suspend"])
    assert_equal Tier[:bronze], r.tier
  end

  test "old reports decay: a fixed regression stops dragging the tier" do
    old = Array.new(2) { entry("2.8", wifi: "broken") }
    r = rating(*old, entry("3.2"))
    assert_equal Tier[:platinum], r.tier
    assert_equal Tier[:platinum], r.trending_tier
    refute r.disputed?, "2 decayed reports should not outvote reality as a dispute"
  end

  test "trending tier only counts the latest minor line" do
    r = rating(entry("3.1"), entry("3.2", audio: "broken"), latest: "3.2.1")
    assert_equal Tier[:bronze], r.trending_tier
    assert_nil rating(entry("3.1"), latest: "3.2").trending_tier
  end

  test "module swap within one SKU is a variant split, not a dispute" do
    intel = { "wifi" => [ "pci:8086:272b" ] }
    mtk = { "wifi" => [ "pci:14c3:0616" ] }
    r = rating(entry(components: intel), entry(components: intel), entry(components: mtk, wifi: "broken"))
    refute r.disputed?
    split = r.variant_splits.fetch("wifi")
    assert_equal({ good: 2, bad: 0 }, split[:by_component][[ "pci:8086:272b" ]])
    assert_equal({ good: 0, bad: 1 }, split[:by_component][[ "pci:14c3:0616" ]])
  end

  test "score sits between 0 and 1 and the API shape matches ProtonDB's" do
    json = rating(entry, entry(install_boot: "broken")).as_json
    assert_equal %i[tier score confidence trending_tier best_reported_tier total_reports disputed], json.keys
    assert_in_delta 0.5, json[:score], 0.01
  end
end
