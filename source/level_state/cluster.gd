class_name Cluster


var entities: Array[Entity] = []


func get_elevation() -> int:
	var elevation := Tile.MINIMUM_HEIGHT
	for entity in entities:
		elevation = maxi(elevation, entity.current_tile.height)

	return elevation
