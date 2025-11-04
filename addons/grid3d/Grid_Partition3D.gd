## 网格分区的godot实现
## 实现了基本的插入和查询还有一些小功能
@tool
class_name GridPartition3D extends Resource

## 一个分区的大小
## 不要手动修改！！！！
@export var cell_size: Vector3 = Vector3(50,50,50)

@export_storage var _cells: Dictionary = {}   # { Vector3: [object...] }
@export_storage var _object_map: Dictionary = {}   # { object: PackedVector3Array }

## 插入对象到覆盖其AABB的所有单元格
func insert(object, aabb: AABB) -> void:
	
	# 如果已存在则先移除旧数据
	if _object_map.has(object):
		remove(object)
		
	# 计算覆盖的单元格坐标
	var cell_coords = _get_cells(aabb)
	
	# 将对象添加到所有覆盖的单元格
	for cell_coord in cell_coords:
		if not _cells.has(cell_coord):
			_cells[cell_coord] = []
		_cells[cell_coord].append(object)
		
	# 记录对象关联的单元格和AABB
	_object_map[object] = cell_coords

## 移除对象及其所有单元格关联
func remove(object) -> void:
	if not _object_map.has(object):
		return
		
	# 获取对象关联的所有单元格
	var cell_coords: PackedVector3Array = _object_map[object]
	
	# 从每个单元格中移除对象引用
	for cell_coord in cell_coords:
		if _cells.has(cell_coord):
			_cells[cell_coord].erase(object)
			
	# 移除对象记录
	_object_map.erase(object)

## 查询与指定AABB相交的所有对象
func query(aabb: AABB) -> Array:
	var result = []
	var seen = {}
	
	# 获取查询范围覆盖的单元格
	var query_cells = _get_cells(aabb)
	
	# 收集所有单元格中的唯一对象
	for cell_coord in query_cells:
		if _cells.has(cell_coord):
			for obj in _cells[cell_coord]:
				if not seen.get(obj, false):
					seen[obj] = true
					result.append(obj)

	return result

## 辅助方法：计算AABB覆盖的单元格坐标
## 注意:PackedVector3Array不能存储Vector3i
func _get_cells(aabb: AABB) -> PackedVector3Array:
	var start = floor(aabb.position/cell_size)
	var end = floor(aabb.end/cell_size)

	var coords = PackedVector3Array()
	
	## 遍历三维网格范围生成所有单元格坐标
	for x in range(start.x, end.x + 1):
		for y in range(start.y, end.y + 1):
			for z in range(start.z, end.z + 1):
				coords.append(Vector3(x, y, z))

	return coords

func get_cell(cell: Vector3) -> Array:
	if _cells.has(cell):
		return _cells[cell]
	return []

## 是否有cell
func is_get_cell(cell:Vector3):
	return _cells.has(cell)

## 点在哪个分区
func has_point(point:Vector3) -> Vector3:
	return floor(point/cell_size)

## 获取cell的坐标
func get_cell_position(cell: Vector3):
	return cell * cell_size
