# A verified tier. Derived from feature statuses, never picked by a user.
class Tier
  include Comparable

  NAMES = %w[borked bronze silver gold platinum].freeze
  LABELS = {
    "platinum" => "Out of the box", "gold" => "Documented tweak", "silver" => "Daily-drivable",
    "bronze" => "Hack needed", "borked" => "Won't install/boot"
  }.freeze
  SCORES = { "platinum" => 1.0, "gold" => 0.8, "silver" => 0.6, "bronze" => 0.3, "borked" => 0.0 }.freeze

  attr_reader :name

  def self.[](name) = ALL.fetch(name.to_s)

  # Untested features are ignored: a desktop has no touchpad, and silence isn't failure.
  def self.from_statuses(statuses)
    s = statuses.select { |_, v| Feature.tested?(v) }
    return self[:borked] if s["install_boot"] == "broken"
    return self[:bronze] if s.any? { |f, v| v == "patched" || (Feature.core?(f) && Feature::RANK[v] <= 1) }
    return self[:silver] if s.any? { |_, v| Feature::RANK[v] <= 1 }
    return self[:gold] if s.value?("works_after_fix")
    self[:platinum]
  end

  def initialize(name) = @name = name
  def rank = NAMES.index(name)
  def <=>(other) = rank <=> other.rank
  def label = LABELS[name]
  def score = SCORES[name]
  def to_s = name

  ALL = NAMES.to_h { [ _1, new(_1).freeze ] }.freeze
end
