@tool
class_name Grid3DNode extends Node3D
## 3D网格节点管理器
##
## 用于管理3D空间中的节点，提供基于网格分区的空间查询、动态加载/卸载和持久化功能。
## 自动处理节点的生命周期和空间更新，支持信号驱动的动态更新。

## 网格分区系统，用于空间索引和查询
## 创建好后不要轻易修改
@export var grid_partition: GridPartition3D :
	set(value):
		grid_partition = value
		id_manager = IDManager.new()
		node_signal_map = {}
		update_configuration_warnings()
## ID管理器，负责生成和管理唯一标识符
@export_storage var id_manager: IDManager
## 节点信号字典，存储节点ID与对应更新信号的映射
@export_storage var node_signal_map: Dictionary
## 节点保存路径，用于持久化存储节点场景文件
## 已经指定目录并且操作后，不要再修改，以免发生错误
@export_global_dir var node_save_path: String :
	set(value):
		node_save_path = value
		_save_directory = DirAccess.open(node_save_path)
		update_configuration_warnings()

## 场景保存文件夹的游标
var _save_directory: DirAccess
## 存储Node3D的实例ID与存储ID的映射，作为缓存
var _node_instance_id_to_storage_id: Dictionary
## 存储存储ID与Node3D的实例ID的映射，作为缓存
var _storage_id_to_node_instance_id: Dictionary

func _is_path_valid():
	return not (node_save_path == "")

func _ready() -> void:
	_save_directory = DirAccess.open(node_save_path)

func _get_configuration_warnings():
	var warnings = []
	
	if grid_partition == null:
		warnings.append("未设置 grid_partition.")
	
	if not _is_path_valid():
		warnings.append("请设置有效路径")
	
	# Returning an empty array means "no warning".
	return warnings



## 节点更新信号回调
##
## 当节点空间位置或尺寸发生变化时调用
func _on_node_updated(bounds = null, node_3d = null):
	if not node_3d or not is_instance_valid(node_3d):
		return
	
	var storage_id = get_storage_id_for_node(node_3d)
	if storage_id != 0:
		_update_node_in_grid(storage_id, bounds, node_3d)
	else:
		push_error("未在grid中找到该node")


## 更新节点在网格中的位置
func _update_node_in_grid(storage_id: int, bounds = null, node_3d = null):
	if bounds != null and (bounds is AABB):
		grid_partition.insert(storage_id, bounds)
	else:
		if node_3d and is_instance_valid(node_3d):
			grid_partition.insert(storage_id, AABB(node_3d.position, Vector3.ZERO))
		else:
			push_error("无法更新节点，节点无效")


## 节点退出场景树回调
##
## 自动清理退出的节点
func _on_node_exiting_tree(node_3d: Node3D):
	if not node_3d or not is_instance_valid(node_3d):
		return
	
	var storage_id = get_storage_id_for_node(node_3d)
	if storage_id != 0:
		_disconnect_node_signals(storage_id)
		if not _save_directory.file_exists(str(storage_id) + ".tscn"):
			id_manager.remove_id(storage_id)
	
	else:
		push_error("未在grid中找到该node")


## 断开节点信号连接
func _disconnect_node_signals(storage_id: int):
	if not node_signal_map.has(storage_id):
		return
	
	var signal_name = node_signal_map[storage_id]
	var instance_id = _storage_id_to_node_instance_id.get(storage_id)
	
	if instance_id:
		var node = instance_from_id(instance_id)
		if node and is_instance_valid(node):
			# 断开更新信号
			if node.has_signal(signal_name) and node.is_connected(signal_name, _on_node_updated):
				node.disconnect(signal_name, _on_node_updated)
			
			# 断开退出树信号
			if node.tree_exiting.is_connected(_on_node_exiting_tree):
				node.tree_exiting.disconnect(_on_node_exiting_tree)
	
	node_signal_map.erase(storage_id)

## 删除磁盘中保存的场景
func _remove_saved_node(storage_id: int):
	if not(_save_directory.file_exists("./" + str(storage_id) + ".tscn")):
		push_error("磁盘中没有 " + str(storage_id) + ".tscn")
	
	var error = _save_directory.remove(node_save_path + str(storage_id) + ".tscn")
	if error != OK:
		push_error("删除为 " + str(storage_id) + " 时发生错误")
	
	if not _storage_id_to_node_instance_id.has(storage_id):
		id_manager.remove_id(storage_id)

## 完全从分区中移除节点
## 断开所有连接并从所有缓存和网格以及磁盘（如果有的话）中移除
func _remove_node_completely(storage_id: int):
	if node_signal_map.has(storage_id):
		_disconnect_node_signals(storage_id)
	
	_remove_saved_node(storage_id)
	grid_partition.remove(storage_id)
	
	var instance_id = _storage_id_to_node_instance_id.get(storage_id)
	if instance_id:
		_node_instance_id_to_storage_id.erase(instance_id)
		_storage_id_to_node_instance_id.erase(storage_id)


## 从网格管理系统中移除节点
func unregister_node(node_3d: Node3D):
	if not node_3d or not is_instance_valid(node_3d):
		push_error("要移除的节点无效")
		return
	
	var storage_id = get_storage_id_for_node(node_3d)
	if storage_id != 0:
		_remove_node_completely(storage_id)
	else:
		push_error("未在grid中找到该node")


func load_node(storage_id: int):
	if not _storage_id_to_node_instance_id.has(storage_id):
		push_error("未在网格中查找到节点")
		return
	
	# 检查节点是否已经存在
	var instance_id = _storage_id_to_node_instance_id[storage_id]
	var existing_node := instance_from_id(instance_id)
	if existing_node and is_instance_valid(existing_node) and existing_node.is_inside_tree():
		existing_node.queue_free()
	
	var file_path = str(storage_id) + ".tscn"
	if not _save_directory.file_exists(file_path):
		push_error("节点文件不存在: " + file_path)
		return
	
	var packed_scene = load(file_path)
	if not packed_scene or not packed_scene is PackedScene:
		push_error("无法加载场景资源: " + file_path)
		return
	
	var instance = packed_scene.instantiate()
	if not instance or not instance is Node3D:
		push_error("实例化的节点不是 Node3D 类型: " + file_path)
		if instance:
			instance.free()
		return
	
	add_child(instance)
	
	# 重新连接信号
	if node_signal_map.has(storage_id):
		var signal_name = node_signal_map[storage_id]
		if instance.has_signal(signal_name):
			instance.connect(signal_name, _on_node_updated.bind(instance))

## 加载指定区域内的节点
##
## 根据AABB区域查询需要加载的节点，并从磁盘加载对应的场景文件
func load_nodes_in_area(bounds: AABB):
	if not grid_partition:
		push_error("GridPartition3D 未初始化")
		return
	
	if node_save_path.is_empty():
		push_error("保存路径未设置")
		return
	
	var storage_ids = grid_partition.query(bounds)
	if not storage_ids:
		return
	
	for storage_id in storage_ids:
		load_node(storage_id)



## 保存节点到磁盘
## 将节点打包为场景文件并保存到指定路径
func save_node_to_disk(node: Node3D):
	if not node or not is_instance_valid(node):
		push_error("要保存的节点无效")
		return
	
	var storage_id = get_storage_id_for_node(node)
	if storage_id == 0:
		push_error("未在grid中找到该node")
		return
	
	if node_save_path.is_empty():
		push_error("保存路径未设置")
		return
	
	if not _save_directory:
		push_error("无法访问保存目录: " + node_save_path.get_base_dir())
		return
	
	var scene = PackedScene.new()
	var result = scene.pack(node)
	if result != OK:
		push_error("打包场景失败，错误码: " + str(result))
		return
	
	var file_path = node_save_path + str(storage_id) + ".tscn"
	var error = ResourceSaver.save(scene, file_path)
	if error != OK:
		push_error("保存场景到磁盘失败，错误码: " + str(error) + "，路径: " + file_path)
	else:
		print("节点保存成功: " + file_path)


## 检查节点是否已注册
## 如果节点已注册返回true，否则返回false
func is_node_registered(node_3d: Node3D) -> bool:
	if not node_3d or not is_instance_valid(node_3d):
		return false
	return _node_instance_id_to_storage_id.has(node_3d.get_instance_id())


## 获取所有已注册节点的ID
func get_all_registered_storage_ids() -> Array:
	return _storage_id_to_node_instance_id.keys()


## 根据ID获取节点实例
func get_node_by_storage_id(storage_id: int) -> Node3D:
	if _storage_id_to_node_instance_id.has(storage_id):
		var instance_id = _storage_id_to_node_instance_id[storage_id]
		return instance_from_id(instance_id)
	return null
	

## 查询指定区域内的节点
func query_nodes_in_bounds(bounds: AABB) -> Array:
	if not grid_partition:
		push_error("GridPartition3D 未初始化")
		return []
	
	var storage_ids = grid_partition.query(bounds)
	var nodes = []
	
	for storage_id in storage_ids:
		var node = get_node_by_storage_id(storage_id)
		if node and is_instance_valid(node):
			nodes.append(node)
	
	return nodes


## 获取节点的存储ID
##
## 如果节点不存在或无效，返回0
func get_storage_id_for_node(node_3d: Node3D) -> int:
	if not node_3d or not is_instance_valid(node_3d):
		return 0
	
	var instance_id = node_3d.get_instance_id()
	if _node_instance_id_to_storage_id.has(instance_id):
		return _node_instance_id_to_storage_id[instance_id]
	else:
		return 0


## 插入节点到网格管理系统
## 节点会被移动到当前节点下，并建立空间索引和信号连接
func register_node(node_3d: Node3D, bounds = null, update_signal_name: String = ""):
	if not node_3d:
		push_error("插入的节点不能为 null")
		return
	
	if not id_manager:
		push_error("ID管理器未设置")
		return
	
	var storage_id = id_manager.generate_id()
	if storage_id <= 0:
		push_error("无法获取有效的ID")
		return
	
	# 检查节点是否已经注册
	if _node_instance_id_to_storage_id.has(node_3d.get_instance_id()):
		push_error("节点已经存在于网格中")
		return
	
	_node_instance_id_to_storage_id[node_3d.get_instance_id()] = storage_id
	_storage_id_to_node_instance_id[storage_id] = node_3d.get_instance_id()
	
	if bounds != null and (bounds is AABB):
		grid_partition.insert(storage_id, bounds)
	else:
		grid_partition.insert(storage_id, AABB(node_3d.position, Vector3.ZERO))
	
	if update_signal_name != "":
		node_3d.connect(update_signal_name, _on_node_updated.bind(node_3d), 16)
		node_signal_map[storage_id] = update_signal_name

	# 监听节点退出树事件，自动清理
	if not node_3d.tree_exiting.is_connected(_on_node_exiting_tree):
		node_3d.tree_exiting.connect(_on_node_exiting_tree.bind(node_3d), 16)
	
	# 将节点添加到当前节点下
	if node_3d.get_parent() != self:
		node_3d.reparent(self)
