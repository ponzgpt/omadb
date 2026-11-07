class HomeController < ApplicationController
  def show
    # ponytail: computes every SKU's layer per request; cache or store the layer past ~1k SKUs.
    @counts = Sku.includes(:reports).find_each.map(&:status_layer).tally
  end
end
