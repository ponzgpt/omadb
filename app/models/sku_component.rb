class SkuComponent < ApplicationRecord
  belongs_to :sku
  belongs_to :component

  def to_part = Prediction::Part.new(kind: component.kind, key: component.key, name: component.name, mapping_confidence:)
end
