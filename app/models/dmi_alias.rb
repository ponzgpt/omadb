# DMI product strings are messy ("20XKCTO1WW", "ThinkPad T14 Gen 2i ", "TO BE FILLED BY O.E.M.").
class DmiAlias < ApplicationRecord
  belongs_to :sku
  before_validation { self.normalized = self.class.normalize(raw) }

  JUNK = /\A(to be filled by o ?e ?m|default string|system product name|system manufacturer|system version|oem|not applicable|none|0+|x+)\z/

  def self.normalize(raw)
    s = raw.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
    s.match?(JUNK) ? nil : s.presence
  end

  def self.resolve(raw) = (n = normalize(raw)) && find_by(normalized: n)&.sku
end
