extends Node
## Autoload "Game": the player's money and looks, kept between sessions on this
## device (user://progress.cfg). Money comes from smashing things (coins.gd picks it
## up), a part of it is lost on death, and the shop (shop.gd) spends it on the
## character's looks and on the bazooka and its rockets. Nothing here is networked
## except the look code, which the other players' screens use to dress this
## player's avatar (net_world.gd).

signal money_changed(value: int)
signal look_changed
signal arsenal_changed

const SAVE_PATH := "user://progress.cfg"
## Share of the money lost when the player dies.
const DEATH_LOSS := 0.25
const FEMALE_MODEL := "res://female_player.glb"
const WHISKEY_PRICE := 100
const WHISKEY_HEAL := 100
## The bazooka: bought once, then every rocket is paid for; at most MAX_ROCKETS carried.
const BAZOOKA_PRICE := 1000
const ROCKET_PRICE := 100
const MAX_ROCKETS := 5

## What the shop sells, per slot, in display order. The first item of every slot is
## free and worn from the start. "color" tints the clothes (null: as painted).
const SLOTS := ["body", "shirt", "pants", "hat", "glasses"]
const SLOT_NAMES := {"body": "Character", "shirt": "T-shirt", "pants": "Jeans", "hat": "Cap", "glasses": "Sunglasses"}
const ITEMS := {
	"body": [
		{"id": "male", "name": "Max", "price": 0},
		{"id": "female", "name": "Alice", "price": 400},
	],
	"shirt": [
		{"id": "black", "name": "Black", "price": 0, "color": null},
		{"id": "white", "name": "White", "price": 60, "color": Color(0.92, 0.92, 0.9)},
		{"id": "red", "name": "Red", "price": 60, "color": Color(0.78, 0.1, 0.1)},
		{"id": "yellow", "name": "Yellow", "price": 60, "color": Color(0.95, 0.78, 0.12)},
		{"id": "green", "name": "Green", "price": 60, "color": Color(0.16, 0.55, 0.26)},
		{"id": "purple", "name": "Purple", "price": 80, "color": Color(0.48, 0.22, 0.7)},
		{"id": "pink", "name": "Pink", "price": 80, "color": Color(0.95, 0.45, 0.65)},
	],
	"pants": [
		{"id": "blue", "name": "Blue", "price": 0, "color": null},
		{"id": "black", "name": "Black", "price": 50, "color": Color(0.1, 0.1, 0.12)},
		{"id": "khaki", "name": "Khaki", "price": 50, "color": Color(0.62, 0.55, 0.38)},
		{"id": "grey", "name": "Grey", "price": 50, "color": Color(0.45, 0.46, 0.48)},
		{"id": "white", "name": "White", "price": 70, "color": Color(0.88, 0.88, 0.86)},
	],
	"hat": [
		{"id": "none", "name": "None", "price": 0},
		{"id": "red", "name": "Red cap", "price": 90, "color": Color(0.78, 0.1, 0.1)},
		{"id": "black", "name": "Black cap", "price": 90, "color": Color(0.08, 0.08, 0.09)},
		{"id": "yellow", "name": "NY cap", "price": 120, "color": Color(0.95, 0.75, 0.1)},
	],
	"glasses": [
		{"id": "none", "name": "None", "price": 0},
		{"id": "dark", "name": "Shades", "price": 70, "color": Color(0.03, 0.03, 0.04)},
		{"id": "gold", "name": "Aviators", "price": 110, "color": Color(0.35, 0.22, 0.05)},
	],
}

var money := 0
## slot -> worn item id
var look := {}
## "slot/id" of everything bought (the free items are always owned)
var owned := {}
var has_bazooka := false
var rockets := 0


func _init() -> void:
	for slot in SLOTS:
		look[slot] = ITEMS[slot][0]["id"]
	_load()


func add_money(amount: int) -> void:
	if amount == 0:
		return
	money = maxi(money + amount, 0)
	money_changed.emit(money)
	_save()


## The player died: a share of the money is gone. Returns how much.
func lose_on_death() -> int:
	var lost := int(floor(money * DEATH_LOSS))
	add_money(-lost)
	return lost


func item(slot: String, id: String) -> Dictionary:
	for entry in ITEMS.get(slot, []):
		if entry["id"] == id:
			return entry
	return {}


## Items the shop can offer: the female body only once her model is in the game.
func is_available(slot: String, id: String) -> bool:
	if slot == "body" and id == "female":
		return ResourceLoader.exists(FEMALE_MODEL)
	return not item(slot, id).is_empty()


func is_owned(slot: String, id: String) -> bool:
	var entry := item(slot, id)
	return not entry.is_empty() and (int(entry["price"]) == 0 or owned.has("%s/%s" % [slot, id]))


## Buy it if needed (and affordable) and put it on. False if it costs more than we have.
func buy_or_wear(slot: String, id: String) -> bool:
	if not is_available(slot, id):
		return false
	if not is_owned(slot, id):
		var price := int(item(slot, id)["price"])
		if price > money:
			return false
		owned["%s/%s" % [slot, id]] = true
		money -= price
		money_changed.emit(money)
	look[slot] = id
	look_changed.emit()
	_save()
	return true


## Buy the bazooka (it comes empty). False if already owned or too dear.
func buy_bazooka() -> bool:
	if has_bazooka or money < BAZOOKA_PRICE:
		return false
	has_bazooka = true
	add_money(-BAZOOKA_PRICE)
	arsenal_changed.emit()
	_save()
	return true


## Buy up to `count` rockets (never past MAX_ROCKETS). Returns how many were bought.
func buy_rockets(count: int) -> int:
	if not has_bazooka:
		return 0
	var n := mini(mini(count, MAX_ROCKETS - rockets), money / ROCKET_PRICE)
	if n <= 0:
		return 0
	rockets += n
	add_money(-n * ROCKET_PRICE)
	arsenal_changed.emit()
	_save()
	return n


## One rocket leaves the tube. False if there are none.
func use_rocket() -> bool:
	if rockets <= 0:
		return false
	rockets -= 1
	arsenal_changed.emit()
	_save()
	return true


## The look as a short string for the network: "female,red,blue,none,dark".
func look_code() -> String:
	var parts := []
	for slot in SLOTS:
		parts.append(str(look.get(slot, ITEMS[slot][0]["id"])))
	return ",".join(parts)


## Turns a look code back into slot -> item; unknown parts fall back to the free item.
static func decode_look(code: String) -> Dictionary:
	var parts := code.split(",")
	var result := {}
	for i in SLOTS.size():
		var slot: String = SLOTS[i]
		var id := parts[i] if i < parts.size() else ""
		var known := false
		for entry in ITEMS[slot]:
			if entry["id"] == id:
				known = true
		result[slot] = id if known else ITEMS[slot][0]["id"]
	return result


## The tint (or null) an item gives, for the model animator.
static func item_color(slot: String, id: String) -> Variant:
	for entry in ITEMS.get(slot, []):
		if entry["id"] == id:
			return entry.get("color")
	return null


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	money = maxi(int(config.get_value("progress", "money", 0)), 0)
	for key in config.get_value("progress", "owned", []):
		owned[str(key)] = true
	has_bazooka = bool(config.get_value("progress", "bazooka", false))
	rockets = clampi(int(config.get_value("progress", "rockets", 0)), 0, MAX_ROCKETS) if has_bazooka else 0
	var saved: Dictionary = decode_look(str(config.get_value("progress", "look", "")))
	for slot in SLOTS:
		if is_owned(slot, saved[slot]):
			look[slot] = saved[slot]


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "money", money)
	config.set_value("progress", "owned", owned.keys())
	config.set_value("progress", "look", look_code())
	config.set_value("progress", "bazooka", has_bazooka)
	config.set_value("progress", "rockets", rockets)
	config.save(SAVE_PATH)
