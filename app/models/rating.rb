# ProtonDB-shaped aggregate over a set of reports (one SKU, or every SKU of a model).
#
# Tier = per feature, the decay-weighted median status across reports; then the tier those
# medians earn. One bad outlier can't sink a machine; a consistent failure can.
class Rating
  # components: { kind => [component keys] }; machine: what the evidence panel names.
  Entry = Data.define(:version, :statuses, :components, :machine) do
    def initialize(version:, statuses:, components: {}, machine: nil)
      version = OmarchyVersion.new(version) unless version.is_a?(OmarchyVersion)
      super(version:, statuses:, components:, machine:)
    end
    def tier = Tier.from_statuses(statuses)
  end

  DISPUTE_SHARE = 0.3 # both sides need at least this share of the weight to count as a fight
  DISPUTE_WINDOW = 1  # minors behind the newest report; older disagreement is history, not a fight

  attr_reader :entries, :latest

  def initialize(entries, latest_version:, half_life: 2.0)
    @entries = entries
    @latest = OmarchyVersion.new(latest_version)
    @half_life = half_life
  end

  def total_reports = entries.size
  def empty? = entries.empty?

  def tier = (Tier.from_statuses(median_statuses) unless empty?)

  def score
    return if empty?
    (entries.sum { weight(_1) * _1.tier.score } / entries.sum { weight(_1) }).round(2)
  end

  def confidence
    case total_reports
    when 0...3 then "inadequate"
    when 3...10 then "good"
    else "strong"
    end
  end

  def trending_tier = Rating.new(entries.select { _1.version.line == latest.line }, latest_version: latest.line).tier
  def best_reported_tier = entries.map(&:tier).max

  def median_statuses
    Feature::ALL.filter_map { |f| (s = median_status(f)) && [ f, s ] }.to_h
  end

  # Core features where reports genuinely disagree and no module variant explains it.
  def disputes
    conflicts.reject { |f| variant_splits.key?(f) }.to_h do |f|
      tested = tested_for(f, recent)
      [ f, tested.group_by { _1.statuses[f] }.transform_values(&:size) ]
    end
  end

  def disputed? = disputes.any?

  # { feature => { kind:, by_component: { key => { good:, bad: } } } } when the outcome tracks the part.
  def variant_splits
    @variant_splits ||= conflicts.each_with_object({}) do |f, splits|
      Feature::KINDS.fetch(f).each do |kind|
        groups = tested_for(f, recent).group_by { _1.components[kind].presence }
        next if groups.size < 2 || groups.key?(nil)
        outcomes = groups.transform_values { |es| es.map { good?(_1.statuses[f]) }.uniq }
        next unless outcomes.values.all? { _1.size == 1 } && outcomes.values.uniq.size > 1
        splits[f] = { kind:, by_component: groups.to_h { |key, es|
          [ key, { good: es.count { good?(_1.statuses[f]) }, bad: es.count { !good?(_1.statuses[f]) } } ]
        } }
        break
      end
    end
  end

  def as_json(*)
    { tier: tier&.name, score:, confidence:, trending_tier: trending_tier&.name,
      best_reported_tier: best_reported_tier&.name, total_reports:, disputed: disputed? }
  end

  private
    def weight(entry) = entry.version.weight_against(latest, half_life: @half_life)
    def good?(status) = Feature::GOOD.include?(status)
    def tested_for(feature, among = entries) = among.select { Feature.tested?(_1.statuses[feature]) }

    # Ties fall to the worse status: we'd rather undersell a machine than oversell it.
    def median_status(feature)
      tested = tested_for(feature).sort_by { Feature::RANK[_1.statuses[feature]] }
      return if tested.empty?
      half = tested.sum { weight(_1) } / 2.0
      running = 0.0
      tested.find { (running += weight(_1)) >= half - 1e-9 }.statuses[feature]
    end

    def recent
      @recent ||= begin
        newest = entries.map(&:version).max_by { [ _1.major, _1.minor ] }
        entries.select { _1.version.minors_behind(newest) <= DISPUTE_WINDOW }
      end
    end

    def conflicts
      @conflicts ||= Feature::CORE.select do |f|
        tested = tested_for(f, recent)
        next false if tested.size < 2
        total = tested.sum { weight(_1) }
        good = tested.select { good?(_1.statuses[f]) }.sum { weight(_1) }
        bad = tested.select { _1.statuses[f] == "broken" }.sum { weight(_1) }
        good / total >= DISPUTE_SHARE && bad / total >= DISPUTE_SHARE
      end
    end
end
