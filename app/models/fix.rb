class Fix < ApplicationRecord
  belongs_to :component, optional: true
  validates :feature, inclusion: { in: Feature::ALL }
  def to_param = slug
end
