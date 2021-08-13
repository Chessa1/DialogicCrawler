extends Node2D


var RNG_OnDefend: RNG_Dialog
var RNG_AtAttack: RNG_Dialog

# --- The 3 maps need to have the SAME size! ---

# 0 - Without Room
# 1 - Explored Room
# 2 - Player Spawn
# 3...N - Rooms Indexes
var map = [
	[0,1,0,1,0],
	[1,3,1,1,0],
	[0,0,2,3,1],
	[0,0,1,0,1],
	[0,3,1,1,1],
]

# 0 - Invisible or Without Room
# 1...N - Visible Rooms Indexes
var visual_map = [
	[0,0,0,0,0],
	[0,0,0,0,0],
	[0,0,2,0,0],
	[0,0,0,0,0],
	[0,0,0,0,0],
]

# 0 - Not Explored
# 1 - Explored
var can_move_map = [
	[0,0,0,0,0],
	[0,0,0,0,0],
	[0,0,0,0,0],
	[0,0,0,0,0],
	[0,0,0,0,0],
]

# Color of each Room Index
# 0 - Don't need to show
# 1 - Empty room
# 2 - Player Spawn
# 3...N - Other Rooms
var room_colors = {
	0 : null,
	1 : Color(1,1,1),
	2 : Color(0,1,0),
	3 : Color(1,0,0)
}

# The location of the player
var player_pos = Vector2()


func _ready():
	# --- RNG Setting Up ---
	randomize()
	# Two RNG_Dialogs to make two different lists
	RNG_OnDefend = RNG_Dialog.new()
	RNG_AtAttack = RNG_Dialog.new()
	add_child(RNG_OnDefend)
	add_child(RNG_AtAttack)

	# Set the dialog list from each of them
	RNG_OnDefend.dialogs = [
		"Timeline2",
		"Timeline3",
	]
	RNG_AtAttack.dialogs = [
		"Timeline4",
		"Timeline5",
	]

	# --- Map Setting Up ---
	for line in range(map.size()):
		for colum in range(map[line].size()):
			# Find the Player Spawn and set it as the player_pos
			if map[line][colum]==2:
				player_pos = Vector2(colum,line)

	# --- Start the game ---
	next_move_decision()


# _draw used to draw the objects of the game, such as the player, the rooms and the paths.
func _draw():
	for line in range(visual_map.size()):
		for colum in range(visual_map[line].size()):
			if visual_map[line][colum]!=0:
				var block_pos = Vector2(colum*175,line*175)
				var block_size = Vector2(50,50)
				draw_rect(Rect2(block_pos,block_size),room_colors[visual_map[line][colum]])
				for i in [Vector2.UP,Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT]:
					if line + i.y < 0 or line + i.y >= map.size():continue
					if colum + i.x < 0 or colum + i.x >= map[line].size():continue
					if map[line+i.y][colum+i.x]==0:continue
					if can_move_map[line][colum]!=1 and can_move_map[line+i.y][colum+i.x]!=1:continue

					draw_line(block_pos+block_size/2+i*45,block_pos+block_size/2+i*90,
					Color(.5,.5,.5),15)

	var block_offset = Vector2(175,175)
	var block_size = Vector2(50,50)
	draw_circle(player_pos*block_offset + block_size/2,50,Color(0,0,0))
	draw_circle(player_pos*block_offset + block_size/2,40,Color(1,1,0))

# _process used to set the camera position and update the _draw function
func _process(delta):
	var block_offset = Vector2(175,175)
	var block_size = Vector2(50,50)
	$Camera2D.position = player_pos*block_offset + block_size/2
	update()


# Get a signal from the Dialogic
func dialogic_signal(argument):
	# -- Movement Actions --
	if argument=="Move_Right":
		_move(Vector2.RIGHT)
	if argument=="Move_Left":
		_move(Vector2.LEFT)
	if argument=="Move_Up":
		_move(Vector2.UP)
	if argument=="Move_Down":
		_move(Vector2.DOWN)
	if argument=="Explore":
		_explore()

	# -- Battle Actions --
	if argument=="Attack" or argument=="Defend":
		var dialog
		var variables = {}
		#  As the dialogic isn't saving the varibles property,
		# we save the values and to reset on the new dialogic node
		for var_ in ["enemy_health","player_health","battle"]:
			variables[var_] = Dialogic.get_variable(var_)
		# Check action
		if argument == "Attack":
			dialog = RNG_AtAttack._start_a_dialog()
		if argument == "Defend":
			dialog = RNG_OnDefend._start_a_dialog()
		# If occurs an error, returns
		if dialog==null:return
		add_child(dialog)
		dialog.connect("dialogic_signal",self,"dialogic_signal")
		# Get the varibles that we saved and reset them
		for i in variables:
			Dialogic.set_variable(i,variables[i])

	if argument=="BattleEnd":
		# When the battle is over, we finish the exploration and check if the player is alive.
		_explore_finish(Dialogic.get_variable("player_health"))


func _explore():
	# What happen on the room, based on his index
	match map[player_pos.y][player_pos.x]:
		3:
			var dialog = Dialogic.start("Timeline1")
			add_child(dialog)
			dialog.connect("dialogic_signal",self,"dialogic_signal")

		_:
			_explore_finish()


func _explore_finish(player_health=null):
	if typeof(player_health)==TYPE_STRING and player_health=="0":
		# PLAYER DIED
		return
	# If the player survives, the room will be empty and already explored
	can_move_map[player_pos.y][player_pos.x] = 1
	map[player_pos.y][player_pos.x] = 1
	visual_map[player_pos.y][player_pos.x] = 1

	next_move_decision()

func _move(direction: Vector2):
	# If is already walking, returns
	if $Tween.is_active():return
	# Get tile and position infos
	var block_offset = Vector2(175,175)
	var block_size = Vector2(50,50)
	var next_pos = player_pos + direction
	# If the next position isn't in the map, returns
	if next_pos.y < 0 or next_pos.y >= map.size():return
	if next_pos.x < 0 or next_pos.x >= map[next_pos.y].size():return
	# If the next position isn't a room, returns
	if map[next_pos.y][next_pos.x]==0:return
	# If the currently position and the next one are both not explored, returns
	if can_move_map[player_pos.y][player_pos.x]!=1 and can_move_map[next_pos.y][next_pos.x]!=1:return
	# Set the visual_map with the same value as the map (row,colum)
	visual_map[next_pos.y][next_pos.x] = map[next_pos.y][next_pos.x]
	# Change player_pos
	$Tween.interpolate_property(self,"player_pos",player_pos,next_pos,0.25)
	$Tween.start()
	yield($Tween,"tween_all_completed")
	next_move_decision()


func next_move_decision():
	var dialog = Dialogic.start("DecideMove")
	add_child(dialog)
	dialog.connect("dialogic_signal",self,"dialogic_signal")

	var directions = {
		Vector2.UP : "up_available",
		Vector2.DOWN : "down_available",
		Vector2.RIGHT : "right_available",
		Vector2.LEFT : "left_available"
	}

	# If the currently room isn't explored, the player will have this option
	if can_move_map[player_pos.y][player_pos.x]!=1:Dialogic.set_variable("explore_available",1)

	# For each direction, check if it's possible to go to those rooms
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT]:
		var next_pos = player_pos + direction
		if next_pos.y < 0 or next_pos.y >= map.size():continue
		if next_pos.x < 0 or next_pos.x >= map[next_pos.y].size():continue
		if map[next_pos.y][next_pos.x]==0:continue
		if can_move_map[player_pos.y][player_pos.x]!=1 and can_move_map[next_pos.y][next_pos.x]!=1:continue
		
		# If is possible, the player will have the option to do it
		Dialogic.set_variable(directions[direction],1)



