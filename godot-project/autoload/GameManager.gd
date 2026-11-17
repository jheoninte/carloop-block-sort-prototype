extends Node

const DEFAULT_PREFIX := "user://carloop_save"
var save_path: String
var temp_path: String
var backup_path: String
var restored_from_backup := false
var writes_blocked := false

func _init(prefix: String = DEFAULT_PREFIX) -> void:
	configure_paths(prefix)

func configure_paths(prefix: String) -> void:
	writes_blocked = false
	save_path = prefix + ".json"
	temp_path = prefix + ".tmp"
	backup_path = prefix + ".bak"

func _read_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4194304:
		return null
	var content := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(content) != OK:
		return null
	return parser.data

func _accepted(data: Variant, validator: Callable) -> bool:
	return data is Dictionary and validator.is_valid() and validator.call(data) == true

func _rename(source: String, target: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(target))

func _remove(path: String) -> Error:
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func load_progress(validator: Callable, incompatible: Callable = Callable()) -> Dictionary:
	restored_from_backup = false
	var primary: Variant = _read_file(save_path)
	var backup: Variant = _read_file(backup_path)
	if incompatible.is_valid():
		writes_blocked = incompatible.call(primary) == true or incompatible.call(backup) == true
	if _accepted(primary, validator):
		return primary
	if _accepted(backup, validator):
		restored_from_backup = true
		return backup
	return {}

func save_progress(runtime_state: Dictionary, validator: Callable) -> bool:
	if writes_blocked:
		return false
	if not _accepted(runtime_state, validator):
		return false
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))
	if directory_error != OK:
		return false
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(runtime_state))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not _accepted(_read_file(temp_path), validator):
		return false
	var primary_valid := _accepted(_read_file(save_path), validator)
	if primary_valid:
		if FileAccess.file_exists(backup_path) and _remove(backup_path) != OK:
			return false
		if _rename(save_path, backup_path) != OK:
			return false
	elif FileAccess.file_exists(save_path) and _remove(save_path) != OK:
		return false
	if _rename(temp_path, save_path) != OK:
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(save_path):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(save_path))
		return false
	return true
