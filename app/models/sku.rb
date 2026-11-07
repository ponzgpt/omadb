# One configuration of a machine. The unit every status layer is decided on.
class Sku < ApplicationRecord
  belongs_to :machine
  has_many :dmi_aliases, dependent: :destroy
  has_many :sku_components, dependent: :destroy
  has_many :components, through: :sku_components
  has_many :reports, dependent: :destroy

  def rating(latest_version: Report.latest_version) = Rating.new(reports.map(&:rating_entry), latest_version:)

  def prediction(evidence: ComponentEvidence.new(Report.where.not(sku: self).map(&:rating_entry)))
    Prediction.new(sku_components.includes(:component).map(&:to_part), evidence)
  end

  # verified | disputed | predicted | unverified — the glyph on every page comes from here.
  def status_layer
    return prediction.layer if reports.none?
    rating.disputed? ? "disputed" : "verified"
  end
end
