## Запускает четыре отдельных процесса игры и проверяет завершение сетевого сценария.
extends SceneTree
var children: Array[int] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://build/lan_test_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var roles: Array[String] = ["host", "mars", "trader", "pirate"]
	var test_port := 30000 + OS.get_process_id() % 20000
	for role in roles:
		var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/lan_peer_probe.gd", "--log-file", directory.path_join(role + ".log"), "--", role, str(test_port)])
		children.append(OS.create_process(OS.get_executable_path(), args))
	var deadline := Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.5).timeout
		var running := false
		for pid in children:
			if pid > 0 and OS.is_process_running(pid):
				running = true
		if not running:
			break
	var failures := 0
	for i in range(roles.size()):
		if children[i] > 0 and OS.is_process_running(children[i]):
			OS.kill(children[i])
		var path := directory.path_join(roles[i] + ".log")
		var log := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "Нет журнала"
		if not ("LAN_PEER %s: 0 ошибок" % roles[i]) in log or "ERROR:" in log:
			failures += 1
			push_error("Сетевой процесс %s: %s" % [roles[i], log])
	print("LAN_NETWORK: %d ошибок; журналы %s" % [failures, directory])
	quit(1 if failures else 0)
