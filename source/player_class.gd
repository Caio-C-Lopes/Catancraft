class_name Player

var player_name: String
var player_color: Color
var ponits: int

var resources := {
	'wood': 0,
	'brick': 0,
	'wheat': 0,
	'sheep': 0,
	'ore': 0
}

func _init(name: String, color: Color):
	player_name = name
	player_color = color
	
func add_resource(resource: String, amount: int):
	if resources.has(resource):
		resources[resource] += amount

func remove_resource(resource: String, amount: int):
	if resources.has(resource):
		resources[resource] -= amount
		
func can_afford(cost: Dictionary):
	for i in cost:
		if resources[i] < cost[i]:
			return false
	return true
