extends PanelContainer

# One narrative objective in the hub's objectives list. Layout is authored in
# scenes/ui/components/objective_row.tscn.
#
# A finished step stays on the list, dimmed and ticked, for the same reason the
# contracts list keeps completed jobs: it reads as progress rather than as
# things silently disappearing.

const DONE_TINT := Color(0.55, 0.55, 0.58, 0.85)


func fill(objective: Dictionary) -> void:
	# Called right after instancing, which can be before _ready has run, so the
	# nodes are fetched directly rather than through onready vars.
	var mark := $Margin/Box/Mark as Label
	var text := $Margin/Box/Text as Label

	text.text = str(objective.get("text", ""))

	if bool(objective.get("done", false)):
		mark.text = "[x]"
		mark.add_theme_color_override("font_color", Color(0.56, 1.0, 0.65))
		modulate = DONE_TINT
	else:
		mark.text = "[ ]"
		mark.add_theme_color_override("font_color", Color(0.78, 0.83, 0.91))
		modulate = Color.WHITE
