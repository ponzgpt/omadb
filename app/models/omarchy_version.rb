# "3.1.2", "4.0.0.alpha" → comparable minor line + decay weight against the latest line.
class OmarchyVersion
  attr_reader :major, :minor

  def initialize(string)
    @major, @minor = Gem::Version.new(string.to_s[/\d+(\.\d+)*/] || "0").segments.values_at(0, 1).map(&:to_i)
  end

  def line = "#{major}.#{minor}"

  # ponytail: assumes < 10 minor releases per major; revisit if Omarchy ever ships x.10.
  def minors_behind(latest) = [ (latest.major - major) * 10 + (latest.minor - minor), 0 ].max

  def weight_against(latest, half_life:) = 0.5**(minors_behind(latest) / half_life)
end
