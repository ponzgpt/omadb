class ModelLine < ApplicationRecord
  belongs_to :vendor
  has_many :machines, dependent: :destroy
end
