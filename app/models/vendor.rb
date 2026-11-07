class Vendor < ApplicationRecord
  has_many :model_lines, dependent: :destroy
  has_many :machines, through: :model_lines
end
