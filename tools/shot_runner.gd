extends Node
##
## Ekran goruntusu alici -- gorseli VARSAYMAK yerine bakmak icin.
##
##   godot --path . -- shot
##
## Cozumun tohumlarini secip zinciri oynatiyor ve belirli anlarda kare
## yakaliyor. Boylece "kurulum" ve "zincir akarken" halleri ayri ayri
## degerlendirilebiliyor.

const OUT := "D:/Temp/mirera-shots"
const LEVELS := [22]

var main: Node


func _ready() -> void:
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(720, 1280))
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(OUT)
	_run()


func _run() -> void:
	await _sec(0.4)
	main._show_title()
	await _sec(0.5)
	await _grab("00_baslik")
	main._show_themes()
	await _sec(0.5)
	await _grab("00_temalar")
	main._themes.visible = false
	await _sec(0.3)

	for lv in LEVELS:
		main.level = lv
		main._start_level()
		await _sec(0.5)
		await _grab("%02d_bos" % lv)

		# Cozumun tohumlarini sec
		var b: BoardView = main.board
		var sol := Solver.solution(b.board, b.par)
		for idx in sol:
			b._tap(b._origin + Vector2((idx % b.board.w) + 0.5,
				(idx / b.board.w) + 0.5) * b._cell)
		await _sec(0.4)
		await _grab("%02d_secili" % lv)

		b.play()
		await _sec(0.9)
		await _grab("%02d_zincir" % lv)
		await _sec(4.2)
		await _grab("%02d_kutlama" % lv)
		await _sec(1.2)
		await _grab("%02d_son" % lv)

	print("SHOTS OK -> ", OUT)
	get_tree().quit()


func _grab(ad: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	print("  kare: ", ad)
	img.save_png("%s/%s.png" % [OUT, ad])


func _sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

## Dil zorlama: --  shot ru   gibi. Yazi tipi kapsamini ve metin tasmasini
## gercekten GORMEK icin; varsaymak yerine bakmak.
func _force_lang() -> void:
	for a in OS.get_cmdline_user_args():
		if a.length() == 2 and Loc.SUPPORTED.has(a):
			Loc.lang = a
			print("[shot] dil zorlandi: ", a)
