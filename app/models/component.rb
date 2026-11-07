# A part identified by bus IDs, e.g. "pci:8086:272b" (Intel BE200), "hda:10ec:0257", "cpu:intel-lunarlake".
class Component < ApplicationRecord
  KINDS = Feature::KINDS.values.flatten.uniq.freeze
  validates :kind, inclusion: { in: KINDS }
  has_many :sku_components, dependent: :destroy
  has_many :skus, through: :sku_components
end
