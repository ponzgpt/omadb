# A model, e.g. "ThinkPad T14 Gen 5 (Intel)". Its SKUs carry the parts and the reports.
class Machine < ApplicationRecord
  belongs_to :model_line
  has_one :vendor, through: :model_line
  has_many :skus, dependent: :destroy
  has_many :reports, through: :skus

  def to_param = slug

  def rating(latest_version: Report.latest_version) = Rating.new(reports.map(&:rating_entry), latest_version:)
end
