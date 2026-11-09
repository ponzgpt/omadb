module ApplicationHelper
  LAYER_GLYPHS = { "verified" => "●", "predicted" => "◐", "unverified" => "○", "disputed" => "~" }.freeze
  STATUS_GLYPHS = { "works" => "✓", "works_after_fix" => "~", "patched" => "~", "partial" => "±", "broken" => "✗" }.freeze

  def layer_glyph(layer) = tag.b(LAYER_GLYPHS.fetch(layer), class: "g-#{layer}", title: layer)

  def tier_badge(tier, prefix: nil)
    return tag.span("no tier yet", class: "muted") unless tier
    tag.span("● #{[ prefix, tier.name ].compact.join(" ")}", class: "t-#{tier.name}", title: tier.label)
  end

  def status_cell(status)
    glyph = STATUS_GLYPHS.fetch(status, "·")
    tag.span("#{glyph} #{status&.humanize&.downcase || "untested"}", class: "s-#{status || "untested"}")
  end
end
