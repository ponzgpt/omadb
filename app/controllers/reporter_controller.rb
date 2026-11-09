# Serves the reporter for `curl -fsSL omadb.technoir.cloud/report | bash`. Plain text, so people can read it first.
class ReporterController < ApplicationController
  SCRIPT = Rails.root.join("reporter/report.sh").read.freeze

  def show
    expires_in 5.minutes, public: true
    render plain: SCRIPT, content_type: "text/plain"
  end
end
