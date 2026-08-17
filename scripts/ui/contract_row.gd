extends PanelContainer

# One contract in the list: who it came from, the goal, live progress, and the
# reward. Layout is authored in scenes/ui/components/contract_row.tscn.
#
# A finished contract is never removed. It dims, says COMPLETED, and the panel
# sorts it to the bottom, so the list doubles as a record of what the run has
# actually delivered rather than only what is still owed.

## How much of its colour a completed row keeps.
const DONE_TINT := Color(0.55, 0.55, 0.58, 0.85)


func fill(contract: Dictionary) -> void:
	# Called right after instancing, which can be before _ready has run, so the
	# nodes are fetched directly rather than through onready vars.
	var from_label := $Margin/Box/TopRow/FromLabel as Label
	var goal_label := $Margin/Box/GoalLabel as Label
	var reward_label := $Margin/Box/RewardLabel as Label
	var status_label := $Margin/Box/TopRow/StatusLabel as Label

	from_label.text = str(contract.get("name", ""))
	goal_label.text = str(contract.get("goal", ""))
	reward_label.text = str(contract.get("reward", ""))

	var done := bool(contract.get("complete", false))
	var target := int(contract.get("target", 0))
	var progress := int(contract.get("progress", 0))

	if done:
		status_label.text = "COMPLETED"
		status_label.add_theme_color_override("font_color", Color(0.56, 1.0, 0.65))
		# Dimmed rather than hidden: the row is a receipt now, not a job.

		modulate = DONE_TINT
	elif target > 1:
		status_label.text = "%d / %d" % [progress, target]
		status_label.add_theme_color_override("font_color", Color(0.78, 0.83, 0.91))
		modulate = Color.WHITE
	else:
		# A one-shot job has nothing useful to show as a fraction.
		status_label.text = "IN PROGRESS"
		status_label.add_theme_color_override("font_color", Color(0.78, 0.83, 0.91))
		modulate = Color.WHITE
