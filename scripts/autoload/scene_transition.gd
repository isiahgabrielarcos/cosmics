extends CanvasLayer

# Fade-to-black between scenes.
#
# Every scene starts under a black cover that lifts over FADE_IN over a
# second, so nothing ever snaps into existence. Changing scene goes the other
# way first: fade down, swap while the screen is black, then fade back up —
# which also hides the frame or two a heavy scene takes to build.
#
# Lives on its own CanvasLayer above everything (including the pick panel at
# 95) and runs on PROCESS_MODE_ALWAYS, so a fade still plays while the tree is
# paused — otherwise leaving a run from the pause menu would sit on a frozen
# image until the new scene appeared.

const FADE_IN := 1.0     # black -> visible on arriving somewhere
const FADE_OUT := 0.45   # visible -> black on leaving

var _cover: ColorRect
var _tween: Tween = null
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Never eats clicks — it's only ever a visual.
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)

	# The first scene of the session gets the same arrival fade as any other.
	get_tree().node_added.connect(_on_node_added)
	fade_in()


## Lifts the cover. Called automatically whenever a scene finishes loading.
func fade_in() -> void:
	_kill()
	_cover.color.a = 1.0
	_tween = create_tween()
	_tween.tween_property(_cover, "color:a", 0.0, FADE_IN)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _busy = false)


## Fades to black, runs `swap`, then fades back in. Use this for anything that
## changes scene so the transition covers the load.
func change_scene(swap: Callable) -> void:
	if _busy:
		return
	_busy = true

	_kill()
	_tween = create_tween()
	_tween.tween_property(_cover, "color:a", 1.0, FADE_OUT)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		swap.call()
		# The new scene's own _ready runs first; fading in from here means the
		# cover lifts on a scene that's already built rather than mid-build.
		fade_in())


func _kill() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


## A scene swapped in by anything that bypassed change_scene still gets the
## arrival fade, so no route into a level can skip it.
func _on_node_added(node: Node) -> void:
	if _busy or node != get_tree().current_scene:
		return
	fade_in()
