@tool
extends EditorPlugin

var grid3dMenu := preload("./Grid3DNode/GUI/Grid3DNodeMenu.tscn").instantiate()
var is_menu_added := false  # 跟踪菜单状态

func _enable_plugin() -> void:
	# Add autoloads here.
	pass
	

func _disable_plugin() -> void:
	# Remove autoloads here.
	
	# 确保移除菜单
	if is_menu_added:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, grid3dMenu)
	
	if is_instance_valid(grid3dMenu):
		grid3dMenu.queue_free()

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass
	
func _handles(object: Object) -> bool:
	return object is Grid3DNode  # 只处理 Grid3DNode 类型

func _edit(object: Object) -> void:
	if object is Grid3DNode:
		# 只有当菜单未添加时才添加
		if not is_menu_added and grid3dMenu.get_parent() == null:
			add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, grid3dMenu)
			grid3dMenu.operation_node = object
			is_menu_added = true
	else:
		# 当选中的不是 Grid3DNode 时移除菜单
		if is_menu_added:
			remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, grid3dMenu)
			grid3dMenu.operation_node = null
			is_menu_added = false

# 可选：当失去焦点时也移除菜单
func _make_visible(visible: bool) -> void:
	if not visible and is_menu_added:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, grid3dMenu)
		is_menu_added = false

func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
