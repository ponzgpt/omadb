require "test_helper"

class TierTest < ActiveSupport::TestCase
  ALL_WORK = Feature::CORE.to_h { [ _1, "works" ] }

  test "all core works is platinum; untested is ignored" do
    assert_equal Tier[:platinum], Tier.from_statuses(ALL_WORK.merge("touchpad" => "untested"))
  end

  test "a documented fix is gold" do
    assert_equal Tier[:gold], Tier.from_statuses(ALL_WORK.merge("audio" => "works_after_fix"))
  end

  test "broken non-core is silver, broken core is bronze, failed install is borked" do
    assert_equal Tier[:silver], Tier.from_statuses(ALL_WORK.merge("fingerprint" => "broken"))
    assert_equal Tier[:bronze], Tier.from_statuses(ALL_WORK.merge("suspend" => "partial"))
    assert_equal Tier[:borked], Tier.from_statuses(ALL_WORK.merge("install_boot" => "broken"))
  end

  test "an out-of-tree fix is bronze even on a non-core feature" do
    assert_equal Tier[:bronze], Tier.from_statuses(ALL_WORK.merge("webcam" => "patched"))
  end

  test "tiers order worst to best" do
    assert_operator Tier[:borked], :<, Tier[:platinum]
  end
end
