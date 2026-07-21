class_name Link


enum Type {
	SOLID,
	STICKY,
}

var type: Type
var entity_a: Entity
var entity_b: Entity


func _init(_type: Type, _entity_a: Entity, _entity_b: Entity) -> void:
	type = _type
	entity_a = _entity_a
	entity_b = _entity_b


func other(entity: Entity) -> Entity:
	return entity_b if entity == entity_a else entity_a
