extends Node
class_name TraderStock

# What Princess has on the shelf this gameplay loop.
#
# Rolled once and then frozen: the same ten items, the same prices, and the
# same sold-out markers survive leaving and re-entering the hub. It only
# rerolls when a run reaches an end screen (GameManager.advance_run_loop), so
# walking out and back in can't be used to reshuffle prices or restock
# something you just bought.
#
# State lives here as statics rather than on the panel, because the panel is
# part of the hub scene and gets rebuilt every time you come back from a run.

static var _slots: Array = []          # [{ item, currency, price }]
static var _sold: Dictionary = {}      # slot index -> true
static var _stocked_for_loop: int = -1


## Rolls a fresh board if this loop hasn't had one yet.
static func ensure_stocked() -> void:
	if _stocked_for_loop == GameManager.run_loop and not _slots.is_empty():
		return
	reroll()


static func reroll() -> void:
	_slots.clear()
	_sold.clear()
	_stocked_for_loop = GameManager.run_loop

	# Draw without replacement so the board never shows the same item twice
	var catalogue: Array = MerchantPanel.CATALOGUE.duplicate()
	catalogue.shuffle()
	var currencies: Array = MerchantPanel.CURRENCIES.keys()

	for i in MerchantPanel.SLOT_COUNT:
		var item: Dictionary = catalogue[i % catalogue.size()]
		var currency: String = currencies[randi_range(0, currencies.size() - 1)]
		var band: Dictionary = MerchantPanel.CURRENCIES[currency]
		# Rounded to something that looks priced rather than generated
		var raw := randi_range(int(band["min"]), int(band["max"]))
		var price := int(round(raw / 5.0)) * 5
		_slots.append({ "item": item, "currency": currency, "price": maxi(5, price) })


static func item(slot: int) -> Dictionary:
	ensure_stocked()
	return _slots[slot]["item"]


static func currency(slot: int) -> String:
	ensure_stocked()
	return _slots[slot]["currency"]


static func price(slot: int) -> int:
	ensure_stocked()
	return int(_slots[slot]["price"])


static func price_text(slot: int) -> String:
	var band: Dictionary = MerchantPanel.CURRENCIES[currency(slot)]
	return "%d %s" % [price(slot), band["label"]]


static func is_sold(slot: int) -> bool:
	return bool(_sold.get(slot, false))


static func can_afford(slot: int) -> bool:
	return int(SaveManager.player_data.get(currency(slot), 0)) >= price(slot)


## Takes the payment and marks the slot sold for the rest of this loop.
static func purchase(slot: int) -> bool:
	if is_sold(slot) or not can_afford(slot):
		return false
	var key := currency(slot)
	SaveManager.player_data[key] = int(SaveManager.player_data.get(key, 0)) - price(slot)
	SaveManager.save_player_data()
	_sold[slot] = true
	return true
