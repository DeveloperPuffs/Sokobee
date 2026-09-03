class_name Logic


static func win_check(state: State) -> bool:
	var block_positions: Array[Vector2i] = []
	for entity in state.entities:
		if entity is Block:
			block_positions.append(entity.current_tile.position)

	for tile: Tile in state.tiles.values():
		if not tile.goal:
			continue

		if not block_positions.has(tile.position):
			return false	

	return true


static func rotate_character_left(character: Character) -> void:
	if character.asleep:
		return

	character.set_facing_direction(Hexagon.get_direction_turned_left(character.facing_direction))


static func rotate_character_right(character: Character) -> void:
	if character.asleep:
		return

	character.set_facing_direction(Hexagon.get_direction_turned_right(character.facing_direction))


static func select_character(state: State, character: Character) -> bool:
	if character == state.active_character:
		return false

	if character.asleep:
		return false

	state.active_character = character
	return true


static func try_move_character(state: State, character: Character, direction: Hexagon.Direction) -> bool:
	if character.asleep:
		return false

	var moving_clusters := _find_moving_clusters(state, character.cluster, direction)

	var move_failed_clusters: Dictionary[Cluster, Entity.MoveFailCause] = {}
	for moving_cluster in moving_clusters:
		var move_fail_cause := _check_cluster_move(state, moving_cluster, direction)
		if move_fail_cause != Entity.MoveFailCause.NONE:
			move_failed_clusters[moving_cluster] = move_fail_cause

	if not move_failed_clusters.is_empty():
		_handle_move_failure(move_failed_clusters, moving_clusters, direction)
		return false

	_handle_move_success(state, character.cluster, direction, moving_clusters)
	return true


# Finds all clusters that would be affected by the given cluster moving in the given direction
# Returns a Dictionary[Cluster, Array[MoveCause]]
static func _find_moving_clusters(state: State, cluster: Cluster, direction: Hexagon.Direction) -> Dictionary[Cluster, Array]:
	var direction_vector := Hexagon.get_direction_vector(direction)

	var moving_clusters: Dictionary[Cluster, Array] = {cluster: []}
	var queued_clusters: Array[Cluster] = [cluster]

	var connect_cluster = func(new_cluster: Cluster, move_cause: MoveCause) -> void:
		if not moving_clusters.has(new_cluster):
			moving_clusters[new_cluster] = []
			queued_clusters.append(new_cluster)

		moving_clusters[new_cluster].append(move_cause)

	while not queued_clusters.is_empty():
		var queued_cluster: Cluster = queued_clusters.pop_front()
		for entity in queued_cluster.entities:
			var target_position := entity.current_tile.position + direction_vector

			for link in entity.links:
				if link.type != Link.Type.STICKY:
					continue

				var other_entity := link.other(entity)
				if other_entity.cluster == queued_cluster:
					continue

				# A sticky link only drags when the move would break the adjacency between its two entities
				var new_offset := target_position - other_entity.current_tile.position
				if Hexagon.is_direction_vector(new_offset):
					continue

				var offset := other_entity.current_tile.position - entity.current_tile.position
				var world_offset := Hexagon.get_tile_world_position(offset)
				var world_direction := Hexagon.get_tile_world_position(direction_vector)
				var blocking := world_offset.dot(world_direction) > 0.0
				var move_cause_kind := MoveCause.Kind.PUSHING if blocking else MoveCause.Kind.DRAGGING
				var move_cause := MoveCause.new(queued_cluster, move_cause_kind)
				connect_cluster.call(other_entity.cluster, move_cause)

			var target_tile: Tile = state.tiles.get(target_position)
			if target_tile == null:
				continue

			for other_entity in state.entities:
				if other_entity.cluster == queued_cluster:
					continue

				if other_entity.current_tile == target_tile:
					var move_cause := MoveCause.new(queued_cluster, MoveCause.Kind.PUSHING)
					connect_cluster.call(other_entity.cluster, move_cause)
					break

	return moving_clusters


static func _check_cluster_move(state: State, cluster: Cluster, direction: Hexagon.Direction) -> Entity.MoveFailCause:
	var direction_vector := Hexagon.get_direction_vector(direction)
	var elevation := cluster.get_elevation()
	var fail_cause := Entity.MoveFailCause.NONE

	for entity in cluster.entities:
		var target_position := entity.current_tile.position + direction_vector
		var target_tile: Tile = state.tiles.get(target_position)

		if target_tile == null:
			if fail_cause == Entity.MoveFailCause.NONE:
				fail_cause = Entity.MoveFailCause.NO_GROUND_AHEAD
			continue

		if target_tile.height > elevation:
			# Blocks cannot be pushed upwards
			if entity is Block:
				return Entity.MoveFailCause.WALL_AHEAD

			# Sleeping characters cannot be pushed upwards
			if entity is Character:
				var character: Character = entity
				if character.asleep:
					return Entity.MoveFailCause.WALL_AHEAD

	return fail_cause


static func _handle_move_success(
	state: State,
	cluster: Cluster,
	direction: Hexagon.Direction,
	moving_clusters: Dictionary[Cluster, Array]
) -> void:
	var cluster_movements: Dictionary[Cluster, Entity.Movement] = {}

	for moving_cluster in moving_clusters:
		cluster_movements[moving_cluster] = Entity.Movement.new(Entity.Movement.Kind.CARRIED)

	if moving_clusters.size() > 1:
		cluster_movements[cluster].kind = Entity.Movement.Kind.INITIATOR
	else:
		cluster_movements[cluster].kind = Entity.Movement.Kind.WALKING

	var resolved_clusters: Dictionary[Cluster, bool] = {cluster: true}

	var change_found := true
	while change_found:
		change_found = false

		for moving_cluster in moving_clusters:
			var move_causes: Array[MoveCause]
			move_causes.assign(moving_clusters[moving_cluster])
			for move_cause in move_causes:
				if not resolved_clusters.has(move_cause.cluster):
					continue

				var cause_movement := cluster_movements[move_cause.cluster]
				var pushed_delay_count := cause_movement.pushed_delay_count
				var dragged_delay_count := cause_movement.dragged_delay_count

				if move_cause.kind == MoveCause.Kind.PUSHING:
					pushed_delay_count += 1
				elif move_cause.kind == MoveCause.Kind.DRAGGING:
					dragged_delay_count += 1

				var comparable_movement := Entity.Movement.new(
					Entity.Movement.Kind.CARRIED,
					pushed_delay_count,
					dragged_delay_count
				)

				if resolved_clusters.has(moving_cluster):
					var original_movement := cluster_movements[moving_cluster]
					if comparable_movement.get_delay_factor() >= original_movement.get_delay_factor():
						continue

				cluster_movements[moving_cluster] = comparable_movement
				resolved_clusters[moving_cluster] = true
				change_found = true

	var direction_vector := Hexagon.get_direction_vector(direction)
	for moving_cluster in cluster_movements:
		for moving_entity in moving_cluster.entities:
			var target_position := moving_entity.current_tile.position + direction_vector
			moving_entity.current_tile = state.tiles[target_position]

	for moving_cluster in cluster_movements:
		var movement := cluster_movements[moving_cluster]
		for moving_entity in moving_cluster.entities:
			moving_entity.moved.emit(movement)


static func _handle_move_failure(
	move_failed_clusters: Dictionary[Cluster, Entity.MoveFailCause],
	moving_clusters: Dictionary[Cluster, Array],
	direction: Hexagon.Direction
) -> void:
	var reacting_clusters: Array[Cluster] = []

	for move_failed_cluster in move_failed_clusters:
		# The chain of clusters that led to this cluster failing to move
		var chained_clusters: Array[Cluster] = []
		var queued_clusters: Array[Cluster] = [move_failed_cluster]
		while not queued_clusters.is_empty():
			var queued_cluster: Cluster = queued_clusters.pop_front()
			if chained_clusters.has(queued_cluster):
				continue

			chained_clusters.append(queued_cluster)

			var move_causes: Array[MoveCause]
			move_causes.assign(moving_clusters[queued_cluster])
			for move_cause in move_causes:
				queued_clusters.append(move_cause.cluster)

			if not reacting_clusters.has(queued_cluster):
				reacting_clusters.append(queued_cluster)

	for reacting_cluster in reacting_clusters:
		var move_fail_cause = move_failed_clusters.get(reacting_cluster, Entity.MoveFailCause.NONE)
		for reacting_entity in reacting_cluster.entities:
			reacting_entity.move_failed.emit(direction, move_fail_cause)


class MoveCause:
	enum Kind {
		PUSHING,
		DRAGGING,
	}

	var cluster: Cluster
	var kind: Kind


	func _init(_cluster: Cluster, _kind: MoveCause.Kind) -> void:
		cluster = _cluster
		kind = _kind
