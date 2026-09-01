extends Node
##
## Magaza ekran goruntusu ureticisi.
##
##   godot --path . -- store        (cihaz dili)
##   godot --path . -- store ru     (belirli dil)
##
## GERCEK OYNANIS yakalaniyor, temsili cizim degil. Magaza gorseli oyunla
## ortusmedigi zaman kullanici indiriyor, hayal kirikligina ugruyor ve dusuk
## puan veriyor -- ASO'da en pahali hata bu. Fusera'da bir kare "bes gorunum"
## vaat edip varsayilan temada bir seviye gosteriyordu; duzeltildi ve ayni
## kural burada bastan uygulaniyor.
##
## Altyazi SAHNEDE ciziliyor, sonradan resme basilmiyor: Godot'un Image
## API'sinde metin cizimi yok, ayrica sahnede cizmek yazi tipinin oyunla
## birebir ayni olmasini garanti ediyor.

const OUT_BASE := "D:/Temp/mirera-store"
const W := 1080
const H := 1920

##
## Her kare: [seviye, altyazi anahtari, cozulmus mu, ozel ekran]
##
## Kare secimi altyaziya GORE yapildi, tersi degil:
##   1  "Aynalari cevir"        -> karisik tahta, henuz cozulmemis
##   2  "Isini hedefe ulastir"  -> cozulmus, isin hedefte yaniyor
##   3  "Az dokunus, cok yildiz"-> kazanma karti, uc yildiz
##   4  "Acilacak bes gorunum"  -> tema ekrani, hepsi acik
##   5  "Kisa bolumler"         -> buyuk tahta, cozulmus
const KARELER := [
	[8, "SHOT_1", false],
	[24, "SHOT_2", true],
	[16, "SHOT_3", true, "kart"],
	[30, "SHOT_4", false, "temalar"],
	[52, "SHOT_5", true],
]

var main: Node
var _out := OUT_BASE
var _afis: Control
var _yazi: Label


func _ready() -> void:
	_force_lang()
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(720, 1280))
	main = get_parent()
	_out = "%s/%s" % [OUT_BASE, Loc.lang]
	DirAccess.make_dir_recursive_absolute(_out)
	_kur()
	await _run()


## Afis serisi: ust bantta yazi, altinda oyun. Yazinin USTTE durmasi
## kasitli -- magazadaki kucuk onizlemede once o okunuyor.
func _kur() -> void:
	_afis = Control.new()
	_afis.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_afis.offset_bottom = 190
	_afis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(_afis)

	var zemin := ColorRect.new()
	zemin.set_anchors_preset(Control.PRESET_FULL_RECT)
	zemin.color = Palette.BG
	_afis.add_child(zemin)

	_yazi = Label.new()
	_yazi.set_anchors_preset(Control.PRESET_FULL_RECT)
	_yazi.offset_left = 44
	_yazi.offset_right = -44
	_yazi.add_theme_font_size_override("font_size", 40)
	_yazi.add_theme_color_override("font_color", Palette.INK)
	_yazi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_yazi.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Uzun ceviriler tek satira sigmiyor.
	_yazi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_afis.add_child(_yazi)


func _run() -> void:
	await _sec(0.4)
	for i in KARELER.size():
		var k: Array = KARELER[i]
		_yazi.text = Loc.t(str(k[1]))
		var ozel := str(k[3]) if k.size() > 3 else ""

		if ozel == "temalar":
			# Kilitli temalar solgun gorunuyor; magaza gorselinde hepsi ACIK
			# olsun ki koleksiyonun tamami gorunsun. Vaat ile goruntu
			# ortusmeli.
			for lv in range(1, 60):
				Save.stars[lv] = 3
			main._show_themes()
			await _sec(0.5)
			await _kaydet(i + 1)
			main._themes.visible = false
			Save.stars.clear()
			continue

		main.level = int(k[0])
		main._start_level()
		# Afis, seviye kurulumunda gizlenen HUD'un ustunde kalmali.
		main.move_child(_afis, main.get_child_count() - 1)
		await _sec(0.55)

		if bool(k[2]):
			var b: BoardView = main.board
			# Cozum gercek DOKUNUS yoluyla uygulaniyor; ic durumu elle
			# kurmak, ekranda gorunen ile oyunun durumu arasinda ayrisma
			# riski dogurur -- yani magaza gorseli oyunu yanlis anlatabilir.
			for idx in Solver.solution(b.grid):
				b._tap(b._origin + Vector2(b.grid.cx(idx) + 0.5,
					b.grid.cy(idx) + 0.5) * b._cell)
			await _sec(1.1)

		if ozel == "kart":
			# Kazanma karti reklamdan sonra aciliyor; burada dogrudan
			# gosteriyoruz ki kare kesin yakalansin.
			await _sec(1.2)
			main._win.visible = true
			main._hud.visible = false
			await _sec(0.4)

		await _kaydet(i + 1)
		main._win.visible = false
	print("STORE OK -> ", _out)
	get_tree().quit()


func _kaydet(no: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	# 720x1280 -> 1080x1920: ikisi de 9:16, oran bozulmuyor.
	img.resize(W, H, Image.INTERPOLATE_LANCZOS)
	img.save_png("%s/%02d.png" % [_out, no])
	print("  kare %d" % no)


func _sec(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _force_lang() -> void:
	for a in OS.get_cmdline_user_args():
		if a.length() == 2 and Loc.SUPPORTED.has(a):
			Loc.lang = a
