extends SceneTree

const SOURCE_PATH := "res://localization/scenarios.csv"
const LOCALES := ["en", "de", "fr", "it", "es", "tr"]


func _initialize() -> void:
	var source := FileAccess.open(SOURCE_PATH, FileAccess.READ)
	if not source:
		push_error("Senaryo çeviri kaynağı açılamadı: %s" % SOURCE_PATH)
		quit(1)
		return
	var header := source.get_csv_line(",")
	if header.size() != LOCALES.size() + 1 or str(header[0]) != "keys":
		push_error("Senaryo çeviri başlığı geçersiz.")
		quit(1)
		return
	var translations: Array[Translation] = []
	for locale in LOCALES:
		var translation := Translation.new()
		translation.locale = locale
		translations.append(translation)
	var row_count := 0
	while not source.eof_reached():
		var row := source.get_csv_line(",")
		if row.size() == 1 and str(row[0]).is_empty():
			continue
		if row.size() != LOCALES.size() + 1:
			push_error("Senaryo çeviri satırı %d sütun yerine %d sütun içeriyor." % [row_count + 2, row.size()])
			quit(1)
			return
		var key := str(row[0])
		for index in range(LOCALES.size()):
			translations[index].add_message(key, str(row[index + 1]))
		row_count += 1
	for index in range(LOCALES.size()):
		var target_path := "res://localization/scenarios.%s.translation" % LOCALES[index]
		var save_error := ResourceSaver.save(translations[index], target_path)
		if save_error != OK:
			push_error("%s yazılamadı: %s" % [target_path, error_string(save_error)])
			quit(1)
			return
	print("SCENARIO_TRANSLATIONS_GENERATED: %d rows x %d locales" % [row_count, LOCALES.size()])
	quit(0)
