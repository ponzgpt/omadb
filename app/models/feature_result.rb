class FeatureResult < ApplicationRecord
  belongs_to :report
  belongs_to :fix, optional: true
  validates :feature, inclusion: { in: Feature::ALL }
  validates :status, inclusion: { in: Feature::STATUSES - %w[patched] }

  # An out-of-tree fix (DKMS, patched kernel) is not a documented tweak: it rates as "patched".
  def effective_status = status == "works_after_fix" && fix&.out_of_tree? ? "patched" : status
end
