extends RefCounted

## Единственное место со старыми идентификаторами фракции: чтение сохранений.
## Новый снимок записывается только с актуальными именами; прогресс не сбрасывается.
static func migrate(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value:
			var renamed: Variant = migrate(key)
			# Актуальное поле имеет приоритет, если снимок содержит обе версии.
			if renamed != key and value.has(renamed):
				continue
			result[renamed] = migrate(value[key])
		return result
	if value is Array:
		var result: Array = value.duplicate()
		for index in result.size():
			result[index] = migrate(result[index])
		return result
	if value is String or value is StringName:
		var text := String(value)
		if text == "orc_warlord":
			return "bandit_raider_leader"
		if text == "orc":
			return "bandit"
		if text.begins_with("orc_"):
			return "bandit_" + text.trim_prefix("orc_")
		if text.begins_with("ork_"):
			return "marauder_" + text.trim_prefix("ork_")
		if text == "warlord":
			return "raider_leader"
		if text == "shaman":
			return "raider_technician"
		if text == "Вождь Гракх Железный Клык":
			return "Главарь Грак"
		if text.begins_with("Вождь "):
			return "Главарь " + text.trim_prefix("Вождь ")
	return value
