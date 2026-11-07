require "test_helper"

class DmiAliasTest < ActiveSupport::TestCase
  test "normalizes case, punctuation and spacing; drops OEM junk" do
    assert_equal "thinkpad t14 gen 2i", DmiAlias.normalize("  ThinkPad T14 Gen 2i ")
    assert_equal "thinkpad t14 gen 2i", DmiAlias.normalize("THINKPAD_T14-Gen 2i")
    assert_nil DmiAlias.normalize("To Be Filled By O.E.M.")
    assert_nil DmiAlias.normalize("Default string")
  end
end
