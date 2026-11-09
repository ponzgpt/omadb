# Files one reporter payload: finds or creates the catalog entry, records parts and feature results.
# Same machine + same Omarchy version again replaces the earlier report instead of stacking votes.
class Report::Intake
  Result = Data.define(:report, :layer_before) do
    def first_on_sku = %w[predicted unverified].include?(layer_before)
  end

  MAX_NOTE = 500

  def initialize(payload) = @probe = Probe.new(payload)

  def call
    payload = @probe.payload
    ApplicationRecord.transaction do
      sku = find_or_create_sku
      layer_before = sku.status_layer
      sku.reports.where(machine_hash: payload["machine_hash"], omarchy_version: version).destroy_all

      report = sku.reports.create!(
        machine_hash: payload["machine_hash"], omarchy_version: version, source: payload["source"],
        channel: payload["channel"].to_s.first(40), kernel: payload["kernel"].to_s.first(80),
        payload: payload.except("note", "machine_hash"),
        notes: (note = payload["note"].to_s.squish.first(MAX_NOTE)).presence,
        notes_status: note.present? ? "pending" : "none"
      )
      @probe.parts.each do |part|
        component = Component.create_with(name: part[:name]).find_or_create_by!(kind: part[:kind], key: part[:key])
        report.report_components.create!(component:)
        sku.sku_components.create_with(source: "report").find_or_create_by!(component:)
      end
      features.each { |feature, status| report.feature_results.create!(feature:, status:) }
      Result.new(report:, layer_before:)
    end
  end

  private
    def version = @probe.payload["omarchy_version"].to_s.squish.first(40).presence || "unknown"

    def features
      Hash(@probe.payload["features"]).slice(*Feature::ALL).select { |_, s| (Feature::STATUSES - %w[patched]).include?(s) }
    end

    def find_or_create_sku
      DmiAlias.resolve(@probe.alias_raw) || begin
        vendor = Vendor.create_with(name: @probe.vendor_name).find_or_create_by!(slug: @probe.vendor_name.parameterize)
        line = vendor.model_lines.create_with(name: @probe.line_name).find_or_create_by!(slug: @probe.line_name.parameterize)
        machine = line.machines.create_with(name: @probe.model_name)
          .find_or_create_by!(slug: "#{vendor.slug}-#{@probe.model_name.parameterize}")
        sku = machine.skus.find_or_create_by!(code: @probe.sku_code)
        sku.dmi_aliases.create!(raw: @probe.alias_raw) if DmiAlias.normalize(@probe.alias_raw)
        sku
      end
    end
end
