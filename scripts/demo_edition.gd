## Ограничения отдельной демо-сборки; полная игра сохраняет все режимы.
extends RefCounted


static func enabled() -> bool:
	# Ключ нужен для проверок до экспорта; экспортный тег нельзя снять ключом.
	return OS.has_feature("demo") or "--demo" in OS.get_cmdline_user_args()


static func accepts_save(snapshot: Dictionary) -> bool:
	return not enabled() or (String(snapshot.get("campaign_map_id", "")) == "mars_demo_v1"
		and snapshot.get("random_map_layout", {}).is_empty()
		and String(snapshot.get("player_faction", "earth")) == "earth")
