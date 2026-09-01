extends Node
##
## Ekran goruntusu alici -- gorseli VARSAYMAK yerine bakmak icin.
##
##   godot --path . -- shot
##   godot --path . -- shot ru        (dili zorlayarak: metin tasiyor mu)
##
## Her bolumun uc hali yakalaniyor: karisik (acilis), tek dokunus sonrasi
## ve cozulmus. Ucu birden gerekli cunku oyunun butun gorsel iddiasi
## isinin YOLUNDA: durgun bir karede aynanin dogru cizilip cizilmedigi
## anlasiliyor, cozulmus karede ise isinin hedefe gercekten vardigi.

const OUT := "D:/Temp/mirera-shots"
const LEVELS := [1, 12, 28, 55]

var main: Node


func _ready() -> void:
	_force_lang()
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
	main._title.visible = false
	await _sec(0.3)

	for lv in LEVELS:
		main.level = lv
		main._start_level()
		await _sec(0.9)
		await _grab("%02d_karisik" % lv)

		var b: BoardView = main.board
		var sol := Solver.solution(b.grid)
		# Once TEK dokunus: yarim cozulmus tahta, isinin yon degistirdigi an.
		if sol.size() > 0:
			_dokun(b, sol[0])
			await _sec(0.6)
			await _grab("%02d_yarim" % lv)
		for i in range(1, sol.size()):
			_dokun(b, sol[i])
		await _sec(1.4)
		await _grab("%02d_cozuldu" % lv)
		await _sec(1.6)
		await _grab("%02d_kart" % lv)

	print("SHOTS OK -> ", OUT)
	get_tree().quit()


## Gercek dokunus yolundan geciyoruz -- dogrudan `grid.toggle` cagirmak
## girdi katmanini atlar ve "ekranda gordugumuz sey oynanan sey mi"
## sorusunu cevapsiz birakirdi.
func _dokun(b: BoardView, idx: int) -> void:
	b._tap(b._origin + Vector2(b.grid.cx(idx) + 0.5, b.grid.cy(idx) + 0.5) * b._cell)


func _grab(ad: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	print("  kare: ", ad)
	img.save_png("%s/%s.png" % [OUT, ad])


func _sec(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Dil zorlama: `-- shot ru` gibi. Yazi tipi kapsamini ve metin tasmasini
## gercekten GORMEK icin; varsaymak yerine bakmak.
func _force_lang() -> void:
	for a in OS.get_cmdline_user_args():
		if a.length() == 2 and Loc.SUPPORTED.has(a):
			Loc.lang = a
			print("[shot] dil zorlandi: ", a)
