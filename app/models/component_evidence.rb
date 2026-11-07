# What reports on OTHER machines say about each part: { [component_key, feature] => { machine => status } }.
# This table is what powers predictions.
class ComponentEvidence
  Fact = Data.define(:works_on, :broken_on, :statuses, :latest_version) do
    def status = statuses.values.sort_by { Feature::RANK[_1] }[(statuses.size - 1) / 2] # median, ties go worse
    def any? = statuses.any?
  end

  NONE = Fact.new(works_on: [], broken_on: [], statuses: {}, latest_version: nil)

  # entries: Rating::Entry with machine set. A machine's newest report wins for that machine.
  def initialize(entries)
    @facts = Hash.new { |h, k| h[k] = {} }
    @versions = {}
    entries.sort_by { [ _1.version.major, _1.version.minor ] }.each do |e|
      e.statuses.each do |feature, status|
        next unless Feature.tested?(status)
        Feature::KINDS.fetch(feature).each do |kind|
          Array(e.components[kind]).each do |key|
            @facts[[ key, feature ]][e.machine] = status
            @versions[[ key, feature ]] = e.version.line
          end
        end
      end
    end
  end

  def for(key, feature)
    statuses = @facts.fetch([ key, feature ], nil) or return NONE
    Fact.new(
      works_on: statuses.select { |_, s| Feature::GOOD.include?(s) }.keys,
      broken_on: statuses.select { |_, s| s == "broken" }.keys,
      statuses:, latest_version: @versions[[ key, feature ]]
    )
  end

  def any_for?(key) = @facts.keys.any? { _1.first == key }
end
