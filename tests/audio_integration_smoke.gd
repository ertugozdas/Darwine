extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	host.name = "AudioIntegrationHost"
	root.add_child(host)

	var music_player := MenuMusicPlayer.new()
	host.add_child(music_player)
	await process_frame
	_expect(music_player.track_count == 5, "Menü playlisti beş müzik içermeli")
	for track_number in range(1, 6):
		var path := "res://sounds/musics/music_%d.mp3" % track_number
		_expect(path in music_player.loaded_track_paths, "%s menü playlistine eklenmeli" % path)
	_expect(
		music_player.track_titles == PackedStringArray(["Iron Dawn", "Waiting in the Cold", "Whisper of the Ramparts", "Mud and Blood", "March of Courage"]),
		"Soundtrack parça adları tanımlı ve doğru sırada olmalı"
	)
	for track_index in range(music_player.track_count):
		_expect(
			str(music_player.get_track_data(track_index).get("subtitle", "")) == "Darwine Soundtrack",
			"%d numaralı parçanın ikinci başlığı Darwine Soundtrack olmalı" % (track_index + 1)
		)
	_expect(
		music_player.current_track_index >= 0 and music_player.current_track_index < music_player.track_count,
		"Playlist ilk açılışta rastgele geçerli bir parça çalmalı"
	)
	_expect(music_player.play_track(1), "İstenen soundtrack parçası seçilebilmeli")
	_expect(music_player.current_track_index == 1, "Seçilen soundtrack indeksi güncellenmeli")
	_expect(music_player.get_current_track_data().get("title") == "Waiting in the Cold", "Seçili parça bilgisi okunabilmeli")
	_expect(music_player.next_track(), "Sonraki parçaya geçilebilmeli")
	_expect(music_player.current_track_index == 2, "Sonraki parça doğru olmalı")
	music_player.next_track()
	_expect(music_player.current_track_index == 3, "Dördüncü parça doğru olmalı")
	_expect(music_player.get_current_track_data().get("title") == "Mud and Blood", "Dördüncü parça adı doğru olmalı")
	music_player.next_track()
	_expect(music_player.current_track_index == 4, "Beşinci parça doğru olmalı")
	_expect(music_player.get_current_track_data().get("title") == "March of Courage", "Beşinci parça adı doğru olmalı")
	music_player.next_track()
	_expect(music_player.current_track_index == 0, "Sonraki parça listenin sonunda başa dönmeli")
	music_player.previous_track()
	_expect(music_player.current_track_index == 4, "Önceki parça listenin başında sona dönmeli")
	_expect(not music_player.toggle_pause(), "Müzik duraklatılabilmeli")
	_expect(music_player.stream_paused, "Duraklatma oynatıcı durumuna yansımalı")
	_expect(music_player.toggle_pause(), "Müzik kaldığı yerden sürdürülebilmeli")
	_expect(not music_player.stream_paused, "Devam ettirilen müzik duraklatılmış olmamalı")
	_expect(music_player.seek_to(1.0), "Parça içinde ileri veya geri sarılabilmeli")

	var zero_volume_player := MenuMusicPlayer.new()
	zero_volume_player.playback_allowed = false
	host.add_child(zero_volume_player)
	await process_frame
	_expect(zero_volume_player.current_track_index >= 0, "Ses %0 iken playlist seçili parçayı korumalı")
	_expect(not zero_volume_player.playing, "Müzik sesi %0 iken şarkı başlamamalı")
	_expect(not zero_volume_player.toggle_pause(), "Müzik sesi %0 iken oynat düğmesi şarkıyı başlatmamalı")
	_expect(not zero_volume_player.playing, "Engellenen oynatma sonrası müzik kapalı kalmalı")
	zero_volume_player.set_playback_allowed(true)
	await process_frame
	_expect(zero_volume_player.is_playback_active(), "Müzik sesi yükseltilince seçili şarkı başlayabilmeli")

	var audio := FeedbackAudio.new()
	host.add_child(audio)
	await process_frame
	for event_id in ["attack", "draw", "ability", "menu_click", "victory"]:
		_expect(audio.has_event(event_id), "Ses sistemi '%s' olayını desteklemeli" % event_id)
		_expect(audio._streams[event_id] is AudioStreamMP3, "'%s' gerçek MP3 efektini kullanmalı" % event_id)
	_expect(audio.has_event("upgrade"), "Sentetik seviye yükseltme geri bildirimi korunmalı")
	_expect(audio.has_event("deploy"), "Kart yerleştirme ayrı ve tok bir ses geri bildirimi sunmalı")
	_expect(audio.has_event("dominion_score"), "Hakimiyet raund puanı ses geri bildirimi sunmalı")
	_expect(audio.has_event("dominion_match_point"), "Hakimiyet maç puanı ayrı ses geri bildirimi sunmalı")

	audio.bind_button_feedback(host)
	var dynamic_button := Button.new()
	host.add_child(dynamic_button)
	await process_frame
	await process_frame
	dynamic_button.button_down.emit()
	_expect(audio.last_event_id == "menu_click", "Sonradan eklenen düğme tıklama efektini çalmalı")

	music_player.stop()
	music_player.stream = null
	zero_volume_player.stop()
	zero_volume_player.stream = null
	audio.set_muted(true)
	for player in audio._players:
		player.stream = null
	await create_timer(0.20).timeout
	host.free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AUDIO_INTEGRATION_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
