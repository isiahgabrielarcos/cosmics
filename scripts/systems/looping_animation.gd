extends Node
class_name LoopingAnimation

# Forces imported 3D animations to loop, without touching import settings.
#
# Neither the .blend nor the exported glTF carries a "loop" flag — Godot decides
# that at import time, which means a re-export from Blender can silently reset
# it. This patches the AnimationPlayer at runtime instead, so it stays fixed.
#
# Usage: drop this node as a child of your imported model (or attach the script
# to the model's root) and set play_on_ready to "laying-loop".

## Clip to start playing in _ready. Leave blank to only fix looping.
@export var play_on_ready: String = ""

## Extra clips to force-loop. Usually unnecessary — anything ending in one of
## loop_suffixes is looped automatically.
@export var also_loop: Array[String] = []

## Blender-side naming convention marking a clip as looping.
@export var loop_suffixes: Array[String] = ["-loop", "-cycle"]

## Loop every clip, ignoring names entirely.
@export var loop_everything: bool = false

## Leave empty to auto-find the AnimationPlayer in this node's tree.
@export var animation_player_path: NodePath

var player: AnimationPlayer


func _ready() -> void:
	player = _find_player()
	if player == null:
		push_warning("LoopingAnimation: no AnimationPlayer found near '%s'." % name)
		return

	_apply_loops()

	if play_on_ready != "":
		play(play_on_ready)


# ── Public ─────────────────────────────────────────────────────────────────────

## Plays a clip, tolerating Blender's exported name mangling — asking for
## "laying-loop" still matches an exported "Armature|laying-loop".
func play(clip_name: String, custom_blend: float = -1.0) -> void:
	var clip := resolve(clip_name)
	if clip == "":
		push_warning("LoopingAnimation: no clip matching '%s'. Available: %s"
			% [clip_name, ", ".join(player.get_animation_list())])
		return
	player.play(clip, custom_blend)


## Returns the real clip name matching `wanted`, or "" if there is none.
func resolve(wanted: String) -> String:
	if player.has_animation(wanted):
		return wanted

	# glTF commonly exports as "<Armature>|<action>"
	for clip in player.get_animation_list():
		var parts := clip.split("|")
		if parts[parts.size() - 1] == wanted:
			return clip

	for clip in player.get_animation_list():
		if clip.to_lower().contains(wanted.to_lower()):
			return clip
	return ""


## Lists every clip the model actually exported — handy when a name won't match.
func print_clips() -> void:
	if player == null:
		print("LoopingAnimation: no AnimationPlayer.")
		return
	print("Clips on '%s': %s" % [player.name, ", ".join(player.get_animation_list())])


# ── Internals ──────────────────────────────────────────────────────────────────

func _apply_loops() -> void:
	for clip_name in player.get_animation_list():
		if not _should_loop(clip_name):
			continue
		var anim := player.get_animation(clip_name)
		if anim != null:
			anim.loop_mode = Animation.LOOP_LINEAR


func _should_loop(clip_name: String) -> bool:
	if loop_everything:
		return true
	for wanted in also_loop:
		if resolve(wanted) == clip_name:
			return true
	for suffix in loop_suffixes:
		if clip_name.ends_with(suffix):
			return true
	return false


func _find_player() -> AnimationPlayer:
	if not animation_player_path.is_empty():
		return get_node_or_null(animation_player_path) as AnimationPlayer

	# own subtree first, then the parent's (owned=false — imported children
	# aren't owned by this node)
	var found := find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		return found[0] as AnimationPlayer

	var parent := get_parent()
	if parent != null:
		found = parent.find_children("*", "AnimationPlayer", true, false)
		if not found.is_empty():
			return found[0] as AnimationPlayer

	return null
