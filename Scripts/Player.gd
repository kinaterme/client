extends Node3D

enum MovingState {
	NONE,
	MOVING,
	ATTACK_MOVING,
}

@export var cam_speed = 15;
@export var min_zoom = 1;
@export var max_zoom = 25;
@export var cur_zoom:int;

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var move_marker: PackedScene = preload("res://Effects/MoveMarker.tscn")
@export var server_listener: Node

var move_state : MovingState

var UI: Script;

#@export var player := 1:
	#set(id):
		#player = id
		#$MultiplayerSynchronizer.set_multiplayer_authority(id)

# Called when the node enters the scene tree for the first time.
func _ready():
	Spring_Arm.spring_length = Config.max_zoom
	Config.camera_property_changed.connect(_on_camera_setting_changed)
# Called every frame. 'delta' is the elapsed time since the previous frame.

func _input(event):
	if event is InputEventMouseMotion:
		try_move(event,false)
		return

	if Input.is_action_just_released("champion_attack_move") or Input.is_action_just_released("champion_move"):
		var raycast = camera_to_mouse_raycast(event.position)
		if not raycast.is_empty():
			place_move_marker(raycast.position)

	if not (Input.is_action_pressed("champion_attack_move") or Input.is_action_pressed("champion_move")):
		move_state = MovingState.NONE
		return

	if Input.is_action_just_pressed("champion_attack_move"):
		move_state = MovingState.ATTACK_MOVING
		try_move(event, true)
		return
	
	if Input.is_action_just_pressed("champion_move"):
		move_state = MovingState.MOVING
		try_move(event, true)



	pass
			
func _on_camera_setting_changed():
	Spring_Arm.spring_length = clamp(Spring_Arm.spring_length, Config.min_zoom, Config.max_zoom)


func try_move(event, show_particle_effect : bool):
	if move_state == MovingState.ATTACK_MOVING:
		attack_move_action(event, show_particle_effect)
		return
	
	if move_state == MovingState.MOVING:
		move_action(event, show_particle_effect)
		return

func move_action(event, show_particle_effect : bool):
	var result = camera_to_mouse_raycast(event.position)
	# Move
	if result and result.collider.is_in_group("ground"):
		result.position.y += 1
		var marker = move_marker.instantiate()
		marker.position = result.position
		get_node("/root").add_child(marker)
		server_listener.rpc_id(get_multiplayer_authority(), "move_to", result.position)
		#Player.MoveTo(result.position)
	# Attack
	if result and result.collider.is_in_group("Objective"):
		server_listener.rpc_id(get_multiplayer_authority(), "target", result.collider.name)
		return
	if result and result.collider.is_in_group("Minion"):
		server_listener.rpc_id(get_multiplayer_authority(), "target", result.collider.name)
		return
	if result and result.collider.is_in_group("Champion"):
		server_listener.rpc_id(get_multiplayer_authority(), "target", result.collider.name)
		return
	if result and result.collider is CharacterBody3D:
		server_listener.rpc_id(get_multiplayer_authority(), "target", result.collider.pid)
		


func attack_move_action(event, show_particle_effect : bool):
	move_action(event, show_particle_effect)


func place_move_marker(location : Vector3):
	var marker = MoveMarker.instantiate()
	marker.position = location
	get_node("/root").add_child(marker);
	

func camera_to_mouse_raycast(target_position : Vector2) -> Dictionary:
	var from = Camera.project_ray_origin(target_position)
	var to = from + Camera.project_ray_normal(target_position) * 1000
	
	var space = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.create(from, to)
	return space.intersect_ray(params)


func _process(delta):
	# ignore all inputs when changing configs since that is annoying
	if Config.in_config_settings:
		return

	# Get Mouse Coords on screen
	var mouse_pos = get_viewport().get_mouse_position()
	var size = get_viewport().size
	var cam_delta = Vector3(0, 0, 0)
	var cam_moved = false
	var edge_margin = Config.edge_margin
	
	# Edge Panning
	if (mouse_pos.x <= edge_margin and mouse_pos.x >= 0) or Input.is_action_pressed("player_left"):
		cam_delta += Vector3(-1,0,0)
		cam_moved = true
	if (mouse_pos.x >= size.x - edge_margin and mouse_pos.x <= size.x) or Input.is_action_pressed("player_right"):
		cam_delta += Vector3(1,0,0)
		cam_moved = true
	if (mouse_pos.y <= edge_margin and mouse_pos.y >= 0) or Input.is_action_pressed("player_up"):
		cam_delta += Vector3(0,0,-1)
		cam_moved = true
	if (mouse_pos.y >= size.y - edge_margin and mouse_pos.y <= size.y) or Input.is_action_pressed("player_down"):
		cam_delta += Vector3(0,0,1)
		cam_moved = true
	
	if cam_moved:
		position += cam_delta.normalized() * delta * Config.cam_speed
	
	# Zoom
	if Input.is_action_just_pressed("player_zoomin"):
		if Spring_Arm.spring_length > Config.min_zoom:
			Spring_Arm.spring_length -= 1;
	if Input.is_action_just_pressed("player_zoomout"):
		if Spring_Arm.spring_length < Config.max_zoom:
			Spring_Arm.spring_length += 1;
	# Recenter
	if Input.is_action_just_pressed("player_cameraRecenter"):
		position = Vector3(0, 0, 0)
	
