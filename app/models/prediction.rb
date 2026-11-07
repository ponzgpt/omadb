# A tier for a SKU nobody has reported yet, built per COMPONENT, never "similar model ⇒ works".
#
# Each feature takes the worst predicted status across its deciding parts, and across every
# alternative part the vendor is known to ship in that slot (you can't pick your wifi module).
class Prediction
  Part = Data.define(:kind, :key, :name, :mapping_confidence) do
    def initialize(kind:, key:, name: key, mapping_confidence: 1.0) = super
  end

  CAP = Tier[:gold]          # a prediction never earns Platinum
  MIN_CORE_COVERAGE = 0.5    # below this, we say "unverified" instead of guessing
  REQUIRED_KINDS = %w[cpu firmware gpu wifi audio_codec].freeze # every laptop and desktop has these

  attr_reader :parts, :evidence

  def initialize(parts, evidence)
    @parts = parts
    @evidence = evidence
  end

  def layer = parts.any? && core_coverage >= MIN_CORE_COVERAGE ? "predicted" : "unverified"
  def predicted? = layer == "predicted"

  def tier = ([ Tier.from_statuses(statuses), CAP ].min if predicted?)

  def statuses
    @statuses ||= Feature::ALL.filter_map do |f|
      known = deciding_parts(f).filter_map { (fact = evidence.for(_1.key, f)).any? && fact.status }
      (s = Feature.worst(known)) && [ f, s ]
    end.to_h
  end

  # Share of the SKU's parts with any evidence at all.
  def coverage = parts.empty? ? 0.0 : (parts.count { evidence.any_for?(_1.key) }.to_f / parts.size).round(2)

  # Coverage discounted by how sure we are that catalog text maps to these exact IDs.
  def confidence = parts.empty? ? 0.0 : (coverage * parts.sum(&:mapping_confidence) / parts.size).round(2)

  # The "why" panel: each part → the verified machines it's proven (or broken) on.
  def why
    parts.map do |part|
      facts = Feature::KINDS.select { |_, kinds| kinds.include?(part.kind) }.keys
        .to_h { [ _1, evidence.for(part.key, _1) ] }.select { |_, fact| fact.any? }
      { part:, alternatives: parts.count { _1.kind == part.kind }, facts: }
    end
  end

  private
    def deciding_parts(feature) = parts.select { Feature::KINDS.fetch(feature).include?(_1.kind) }

    def core_coverage
      kinds = REQUIRED_KINDS | (Feature::CORE.flat_map { Feature::KINDS[_1] } & parts.map(&:kind))
      kinds.count { |k| parts.select { _1.kind == k }.any? { evidence.any_for?(_1.key) } }.to_f / kinds.size
    end
end
