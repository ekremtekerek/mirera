extends Node
##
## Gercek giris yolu sinamasi.
##
##   godot --path . -- probe
##
## Simdiye kadarki araclar (`store`, `shot`) tahtayi ic metotlari cagirarak
## suruyordu: `board._tap(...)`. Bu, oyunun GORUNTUSUNU dogruluyor ama
## DOKUNMA yolunu hic sinamiyor -- olay viewport'a girip GUI agacinda dogru
## Control'e ulasiyor mu, bunu hic olcmedik. Telefonda daireler tiklanmayinca
## acigin tam orada oldugu anlasildi.
##
## Burada olay `get_viewport().push_input()` ile GERCEKTEN gonderiliyor:
## viewport isabet testini yapiyor, uste binen bir dugum varsa olayi o yiyor
## ve sinama duser. Yani bu sinama, uzerine binen gorunmez bir katmani da
## yakalar.

var main: Node
var board: BoardView


var _dustu := false


func _ready() -> void:
	main = get_parent()
	await get_tree().process_frame
	await _kos()
	get_tree().quit(1 if _dustu else 0)


func _kos() -> void:
	main.level = int(_arg_seviye())
	main._start_level()
	board = main.board
	await get_tree().process_frame
	await get_tree().process_frame

	var hedef := _ilk_tohum()
	if hedef < 0:
		print("PROBE HATA: tahtada tohum yok")
		return

	var yerel: Vector2 = board._center(hedef)
	var ekran: Vector2 = board.global_position + yerel
	print("tohum idx=%d  tahta-yerel=%s  ekran=%s  hucre=%.1f"
		% [hedef, yerel, ekran, board._cell])

	# Rehber halkasi ve dugme yazisi gorsel olarak dogrulanmali: sayilar
	# dogru olsa da halka yanlis yerde ya da hic cizilmemis olabilir.
	Save.taught = false
	main._rehber_kur()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("D:/Temp/mirera-check")
	get_viewport().get_texture().get_image().save_png(
		"D:/Temp/mirera-check/rehber.png")
	print("rehber-goruntu yazildi  guide=", board.guide,
		"  dugme=[", main._btn_play.text, "]")

	# 1) Fare olayi -- Android'de dokunma varsayilan olarak buna cevriliyor.
	var onceki: int = board._selected.size()
	_bas_birak(ekran, false)
	await get_tree().process_frame
	var fare := board._selected.size() != onceki
	print("fare olayi tohumu secti mi: ", fare)

	# 2) Dokunma olayi -- cevrim kapaliysa bu yol kullaniliyor.
	board._selected.clear()
	board.queue_redraw()
	await get_tree().process_frame
	_bas_birak(ekran, true)
	await get_tree().process_frame
	var dokunma := board._selected.size() > 0
	print("dokunma olayi tohumu secti mi: ", dokunma)

	print("seviye %d  par=%d  butce=%d  secili=%d  BASLAT-kapali=%s"
		% [main.level, board.par, board.budget, board._selected.size(),
		str(main._btn_play.disabled)])
	print("ipucu metni: [", main._lbl_hint.text, "]")


	# 3) ANDROIDIN GERCEK DURUMU: tek dokunus iki olay uretiyor --
	# InputEventScreenTouch, ardindan cihaz kimligi -1 olan SAHTE bir fare
	# olayi. Sinamalar bunu hic uretmedigi icin hata masaustunde gorunmedi:
	# oyun telefonda tohumu secip hemen birakiyordu.
	board._selected.clear()
	board.dbg_gui = 0
	board.dbg_tap = 0
	board.dbg_hit = 0
	await get_tree().process_frame
	_bas_birak(ekran, true)
	_sahte_fare(ekran)
	await get_tree().process_frame
	var tek := board._selected.size() == 1
	print("  olculen: gui=", board.dbg_gui, " tap=", board.dbg_tap,
		" hit=", board.dbg_hit)
	print("cift olay sonrasi secili=", board._selected.size(),
		"  (1 olmali)")

	if not tek:
		_dustu = true
		print("PROBE DUSTU -- tek dokunus iki kez islendi")
		return

	if fare and dokunma:
		print("PROBE OK")
	else:
		_dustu = true
		print("PROBE DUSTU -- olay tahtaya ulasmiyor")


## Seviye numarasi komut satirindan: "-- probe 1" ilk seviyeyi sinar.
func _arg_seviye() -> int:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			return maxi(1, int(a))
	return 4


func _bas_birak(ekran: Vector2, dokunma: bool) -> void:
	for basildi in [true, false]:
		var e: InputEvent
		if dokunma:
			var t := InputEventScreenTouch.new()
			t.index = 0
			t.position = ekran
			t.pressed = basildi
			e = t
		else:
			var m := InputEventMouseButton.new()
			m.button_index = MOUSE_BUTTON_LEFT
			m.position = ekran
			m.global_position = ekran
			m.pressed = basildi
			e = m
		get_viewport().push_input(e, true)


## Androidin urettiği SAHTE fare olayi: cihaz kimligi DEVICE_ID_EMULATION.
func _sahte_fare(ekran: Vector2) -> void:
	for basildi in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.position = ekran
		m.global_position = ekran
		m.pressed = basildi
		m.device = InputEvent.DEVICE_ID_EMULATION
		get_viewport().push_input(m, true)


func _ilk_tohum() -> int:
	for i in board.board.cells.size():
		if Tiles.kind(board.board.cells[i]) == Tiles.SEED:
			return i
	return -1
