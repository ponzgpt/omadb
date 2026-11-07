require "test_helper"

class PredictionTest < ActiveSupport::TestCase
  CPU = Prediction::Part.new(kind: "cpu", key: "cpu:intel-lunarlake")
  FW = Prediction::Part.new(kind: "firmware", key: "fw:lenovo")
  GPU = Prediction::Part.new(kind: "gpu", key: "pci:8086:64a0")
  WIFI = Prediction::Part.new(kind: "wifi", key: "pci:8086:272b")
  AUDIO = Prediction::Part.new(kind: "audio_codec", key: "hda:10ec:0257")
  MTK = Prediction::Part.new(kind: "wifi", key: "pci:14c3:0616")
  BASE = [ CPU, FW, GPU, WIFI, AUDIO ].freeze

  def evidence(*entries) = ComponentEvidence.new(entries)

  def report(machine, components, **statuses)
    Rating::Entry.new(version: "3.2", machine:, components: components.group_by(&:kind).transform_values { _1.map(&:key) },
      statuses: Feature::CORE.to_h { [ _1, "works" ] }.merge(statuses.transform_keys(&:to_s)))
  end

  test "every part proven elsewhere is still capped at gold" do
    p = Prediction.new(BASE, evidence(report("X1 Carbon", BASE)))
    assert_equal "predicted", p.layer
    assert_equal Tier[:gold], p.tier
    assert_equal 1.0, p.coverage
    assert_equal [ "X1 Carbon" ], p.why.find { _1[:part] == WIFI }[:facts]["wifi"].works_on
  end

  test "one unknown part lowers confidence but not the tier" do
    sku = BASE + [ Prediction::Part.new(kind: "fingerprint", key: "usb:06cb:00fc") ]
    p = Prediction.new(sku, evidence(report("X1 Carbon", BASE)))
    assert_equal Tier[:gold], p.tier
    assert_operator p.confidence, :<, 1.0
    assert_empty p.why.last[:facts]
  end

  test "a part broken on other machines drags the prediction down" do
    p = Prediction.new(BASE, evidence(report("X1 Carbon", BASE, audio: "broken"), report("Yoga", BASE, audio: "broken")))
    assert_equal "broken", p.statuses["audio"]
    assert_equal Tier[:bronze], p.tier
  end

  test "module lottery: the worst known alternative decides the slot" do
    ev = evidence(report("X1 Carbon", BASE), report("Zenbook", [ CPU, FW, GPU, MTK, AUDIO ], wifi: "broken"))
    p = Prediction.new(BASE + [ MTK ], ev)
    assert_equal "broken", p.statuses["wifi"]
    assert_equal 2, p.why.find { _1[:part] == MTK }[:alternatives]
  end

  test "marketing-text mapping lowers confidence" do
    fuzzy = BASE.map { _1.with(mapping_confidence: 0.4) }
    assert_equal 0.4, Prediction.new(fuzzy, evidence(report("X1 Carbon", BASE))).confidence
  end

  test "too little evidence on core parts stays unverified" do
    p = Prediction.new(BASE, evidence(report("Desktop", [ AUDIO ])))
    assert_equal "unverified", p.layer
    assert_nil p.tier
    assert_equal "unverified", Prediction.new([], evidence).layer
  end
end
