class ReportsController < ApplicationController
  MAX_BYTES = 64.kilobytes

  skip_forgery_protection # no session, no cookies: the reporter is curl
  wrap_parameters false
  rate_limit to: 10, within: 1.hour, by: -> { request.remote_ip }, name: "ip",
    with: -> { render json: { error: "Too many reports from this address. Try again in an hour." }, status: :too_many_requests }
  rate_limit to: 3, within: 1.hour, by: -> { params[:machine_hash].to_s }, name: "machine",
    with: -> { render json: { error: "This machine just reported. Try again in an hour." }, status: :too_many_requests }

  def create
    return head :content_too_large if request.content_length.to_i > MAX_BYTES
    result = Report::Intake.new(request.request_parameters).call
    report = result.report
    rating = report.sku.rating
    render status: :created, json: {
      machine: "#{report.machine.vendor.name} #{report.machine.name}", url: machine_url(report.machine),
      tier: report.rating_entry.tier.name, machine_tier: rating.tier&.name,
      layer_before: result.layer_before, first_on_sku: result.first_on_sku
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
  end
end
