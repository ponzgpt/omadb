# The features a report rates, and which parts decide each one (used to blame/credit components).
module Feature
  CORE = %w[install_boot display gpu_accel wifi audio suspend touchpad keyboard].freeze
  NON_CORE = %w[bluetooth webcam fingerprint battery fn_keys usbc_display hybrid_gpu].freeze
  ALL = (CORE + NON_CORE).freeze

  # "patched" is works_after_fix where the fix is out-of-tree (DKMS, patched kernel): it forces Bronze.
  STATUSES = %w[works works_after_fix patched partial broken untested].freeze
  RANK = { "works" => 4, "works_after_fix" => 3, "patched" => 2, "partial" => 1, "broken" => 0 }.freeze
  GOOD = %w[works works_after_fix].freeze

  # ponytail: one feature → its deciding component kinds; a broken feature blames every kind listed.
  KINDS = {
    "install_boot" => %w[cpu firmware], "display" => %w[gpu], "gpu_accel" => %w[gpu],
    "wifi" => %w[wifi], "audio" => %w[audio_codec], "suspend" => %w[cpu firmware],
    "touchpad" => %w[touchpad], "keyboard" => %w[firmware], "bluetooth" => %w[bluetooth],
    "webcam" => %w[webcam], "fingerprint" => %w[fingerprint], "battery" => %w[firmware],
    "fn_keys" => %w[firmware], "usbc_display" => %w[gpu], "hybrid_gpu" => %w[gpu]
  }.freeze

  def self.core?(feature) = CORE.include?(feature)
  def self.tested?(status) = RANK.key?(status)
  def self.worst(statuses) = statuses.select { tested?(_1) }.min_by { RANK[_1] }
end
