class MachinesController < ApplicationController
  def show
    @machine = Machine.includes(skus: { reports: [ :feature_results, :components ] }).find_by!(slug: params[:id])
    @rating = @machine.rating
    respond_to do |format|
      format.html
      format.json { render json: @rating.as_json.merge(machine: @machine.name, skus: @machine.skus.to_h { [ _1.code, _1.status_layer ] }) }
    end
  end
end
