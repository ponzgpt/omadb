class Report < ApplicationRecord
  belongs_to :sku
  has_one :machine, through: :sku
  has_many :feature_results, dependent: :destroy
  has_many :report_components, dependent: :destroy
  has_many :components, through: :report_components

  validates :source, inclusion: { in: %w[installed live_iso] }
  validates :machine_hash, format: { with: /\A[0-9a-f]{32}\z/ }

  # ponytail: newest version seen in reports; swap for the Omarchy release feed once we track it.
  def self.latest_version
    distinct.pluck(:omarchy_version).max_by { (v = OmarchyVersion.new(_1)) && [ v.major, v.minor ] } || "0.0"
  end

  def rating_entry
    Rating::Entry.new(
      version: omarchy_version,
      statuses: feature_results.to_h { [ _1.feature, _1.effective_status ] },
      components: components.group_by(&:kind).transform_values { _1.map(&:key) },
      machine: sku.machine.name
    )
  end
end
