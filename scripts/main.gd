extends Control
##
## Oyun akisi: baslik -> bolum -> kazanma karti -> sonraki bolum.
##
## Arayuz kodla kuruluyor, sahne dosyasiyla degil. Sebep pratik: tek bir
## palet degisikligi butun ekrani birden guncelliyor ve tema denemeleri
## sahne dosyalarini elle duzeltmeyi gerektirmiyor.

const HEADER_H := 118.0
const FOOTER_H := 150.0

var level := 1

var board: BoardView
var _root: Control
var _title: Control
var _hud: Control
var _win: Control
var _themes: Control
var _lbl_level: Label
var _lbl_taps: Label
var _btn_hint: Button
var _toast: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	board = BoardView.new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.offset_top = HEADER_H
	board.offset_bottom = -FOOTER_H
	board.solved.connect(_on_solved)
	board.taps_changed.connect(_on_taps)
	_root.add_child(board)

	_build_hud()
	_build_title()
	_build_win()
	_build_themes()
	_themes.visible = false
	_show_title()

	# Ekran goruntusu / ikon araclari sahneye buradan takiliyor. Oyunun
	# kendi akisina hic dokunmuyorlar, yalnizca disaridan surukluyorlar.
	for a in OS.get_cmdline_user_args():
		if a == "store":
			add_child(load("res://tools/store_shots.gd").new())
		if a == "icon":
			add_child(load("res://tools/icon_gen.gd").new())
		if a == "probe":
			add_child(load("res://tools/input_probe.gd").new())
		if a == "shot":
			add_child(load("res://tools/shot_runner.gd").new())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BG, true)


# ------------------------------------------------------------------ parcalar

func _label(text: String, boyut: int, renk: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", boyut)
	l.add_theme_color_override("font_color", renk)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


##
## Uc boyutlu his veren dugme.
##
## Numara basit ama etkili: govdenin ALT KENARI kalin ve koyu ciziliyor --
## bu, dugmenin bir yuzeyden yukselen kalin bir tas oldugu izlenimini
## veriyor. Basildiginda alt kenar inceliyor ve metin asagi kayiyor, yani
## dugme gercekten ICERI cokuyor.
##
## Duz renkli dikdortgen dugmeler dokunmatikte "basildi mi" geri bildirimini
## yalnizca renkle veriyor; hareket geri bildirimi cok daha net.
func _button(text: String, birincil: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(228, 88)
	b.add_theme_font_size_override("font_size", 32)

	var yuz := Palette.ACCENT if birincil else Palette.BTN_FACE
	var kenar := Palette.ACCENT_DEEP if birincil else Palette.BTN_EDGE
	var kalinlik := 9

	var normal := StyleBoxFlat.new()
	normal.bg_color = yuz
	normal.set_corner_radius_all(26)
	normal.border_width_bottom = kalinlik
	normal.border_color = kenar
	normal.content_margin_left = 30
	normal.content_margin_right = 30
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6 + kalinlik
	normal.shadow_color = Color(0, 0, 0, 0.10)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 4)

	var hover := normal.duplicate()
	hover.bg_color = yuz.lightened(0.07)

	var pressed := normal.duplicate()
	pressed.bg_color = yuz.darkened(0.04)
	pressed.border_width_bottom = 2
	pressed.content_margin_top = 6 + (kalinlik - 2)
	pressed.content_margin_bottom = 6 + 2
	pressed.shadow_size = 3
	pressed.shadow_offset = Vector2(0, 1)

	var disabled := normal.duplicate()
	disabled.bg_color = yuz.lerp(Palette.BG_DEEP, 0.55)
	disabled.border_color = kenar.lerp(Palette.BG_DEEP, 0.55)
	disabled.shadow_color = Color(0, 0, 0, 0.04)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color",
		Color.WHITE if birincil else Palette.INK)
	b.add_theme_color_override("font_disabled_color",
		Color(1, 1, 1, 0.6) if birincil else Palette.INK_SOFT)
	return b


# ---------------------------------------------------------------- oyun ekrani

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)

	_lbl_level = _label("", 44, Palette.INK)
	_lbl_level.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_lbl_level.offset_top = 54
	_lbl_level.offset_bottom = 110
	_hud.add_child(_lbl_level)

	_lbl_taps = _label("", 26, Palette.INK_SOFT)
	_lbl_taps.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_lbl_taps.offset_top = 112
	_lbl_taps.offset_bottom = 152
	_hud.add_child(_lbl_taps)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -FOOTER_H + 30
	bar.offset_bottom = -32
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 20)
	_hud.add_child(bar)

	var reset := _button(Loc.t("BTN_RESET"), false)
	reset.pressed.connect(func() -> void:
		Sfx.tap()
		board.reset_level())
	bar.add_child(reset)

	_btn_hint = _button(Loc.t("BTN_HINT"), true)
	_btn_hint.pressed.connect(_ipucu_iste)
	bar.add_child(_btn_hint)

	# Kisa bildirim. Ustte degil ALTTA duruyor: oyuncunun parmagi tahtanin
	# uzerinde ve ustteki bir mesaj gozden kaciyor.
	_toast = _label("", 24, Palette.ACCENT)
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_top = -FOOTER_H - 42
	_toast.offset_bottom = -FOOTER_H - 6
	_toast.visible = false
	_hud.add_child(_toast)


##
## Ipucu: odullu reklam karsiligi BIR ayna isaretleniyor.
##
## Dugme reklam yuklu olmasa bile GORUNUYOR ve basilinca kisa bir sure
## bekliyor. Onceki tasarimda dugme yalnizca reklam hazirsa cikiyordu;
## oyuncunun gordugu sey tikandigi seviyede hicbir cikis yolu olmayan bir
## ekrandi ve oyun bozuk gorunuyordu.
##
## Reklam yine gelmezse sebep SOYLENIYOR: mesajin sonundaki asama etiketi
## "reklam yok" ile "SDK hic baslamadi" arasindaki farki uzaktan ayirt
## etmeyi mumkun kiliyor.
func _ipucu_iste() -> void:
	Sfx.tap()
	if not Ads.rewarded_possible():
		# Reklamsiz satin alan ya da masaustu: odul bedava.
		if board.mark_hint():
			_bildir(Loc.t("TOAST_HINT"))
		return
	_btn_hint.disabled = true
	var hazir := await Ads.await_rewarded(8.0)
	if hazir and await Ads.show_rewarded("hint"):
		if board.mark_hint():
			_bildir(Loc.t("TOAST_HINT"))
	else:
		_bildir("%s (%s)" % [Loc.t("TOAST_AD_NONE"), Ads.asama()])
	_btn_hint.disabled = false


func _bildir(metin: String) -> void:
	_toast.text = metin
	_toast.visible = true
	await get_tree().create_timer(2.4).timeout
	_toast.visible = false


# ------------------------------------------------------------------- baslik

func _build_title() -> void:
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title)

	# Baslik amblemi: KUCUK, COZULMUS ve CANLI bir tahta.
	#
	# Statik bir logo yerine oyunun kendisi duruyor -- isin akiyor, hedef
	# nabiz atiyor. Bir bulmaca oyununun ilk ekranda cevaplamasi gereken
	# soru "bu oyun ne", ve buna bir cumleden hizli cevap veren sey oyunun
	# calisan halidir. Ayni BoardView kullaniliyor, yani amblem hicbir zaman
	# oyunun gercek gorunumunden ayrisamiyor.
	var amblem := BoardView.new()
	amblem.set_anchors_preset(Control.PRESET_CENTER_TOP)
	amblem.offset_left = -170
	amblem.offset_right = 170
	amblem.offset_top = 200
	amblem.offset_bottom = 480
	amblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amblem.load_level({"grid": _amblem_tahtasi(), "par": 0})
	_title.add_child(amblem)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -250
	v.offset_right = 250
	v.offset_top = -170
	v.offset_bottom = 290
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 20)
	_title.add_child(v)

	v.add_child(_label("MIRERA", 78, Palette.INK))
	v.add_child(_label(Loc.t("TITLE_TAG"), 26, Palette.INK_SOFT))
	v.add_child(Control.new())

	var play := _button(Loc.t("BTN_PLAY"), true)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void:
		Sfx.tap()
		level = maxi(1, Save.unlocked)
		_start_level())
	v.add_child(play)

	var tema := _button("", false)
	tema.name = "ThemeBtn"
	tema.custom_minimum_size = Vector2(300, 68)
	tema.add_theme_font_size_override("font_size", 24)
	tema.pressed.connect(func() -> void:
		Sfx.tap()
		_show_themes())
	v.add_child(tema)

	var shop := _button("", false)
	shop.name = "Shop"
	shop.custom_minimum_size = Vector2(300, 76)
	shop.add_theme_font_size_override("font_size", 26)
	shop.pressed.connect(func() -> void:
		Sfx.tap()
		await Store.purchase("no_ads")
		_show_title())
	v.add_child(shop)

	# Geri yukleme: Google bu akisin KULLANICIYA ULASILABILIR olmasini
	# zorunlu tutuyor. Acilistaki sessiz geri yukleme yetmiyor.
	var rest := _button("", false)
	rest.name = "Restore"
	rest.custom_minimum_size = Vector2(300, 64)
	rest.add_theme_font_size_override("font_size", 22)
	rest.pressed.connect(func() -> void:
		Sfx.tap()
		Store.restore())
	v.add_child(rest)

	var stats := _label("", 24, Palette.INK_SOFT)
	stats.name = "Stats"
	v.add_child(stats)


##
## Amblem tahtasi: kaynak -> ayna -> ayna -> hedef, hepsi DOGRU yonelimde.
## Uretilen bir bolum kullanmadim: amblemin her acilista ayni olmasi ve
## karisik degil COZULMUS gorunmesi gerekiyor. Karisik bir tahta "bozuk"
## okunuyor, cozulmus tahta ise mekanigi tek bakista anlatiyor.
func _amblem_tahtasi() -> Grid:
	var g := Grid.new(3, 3)
	g.kind[g.idx(0, 2)] = Grid.SOURCE
	g.state[g.idx(0, 2)] = Grid.YON_SAG
	g.kind[g.idx(2, 2)] = Grid.MIRROR
	g.state[g.idx(2, 2)] = 0                    # "/" -> sag'dan yukari
	g.kind[g.idx(2, 0)] = Grid.MIRROR
	g.state[g.idx(2, 0)] = 1                    # "\" -> yukaridan sola
	g.kind[g.idx(0, 0)] = Grid.TARGET
	return g


func _show_title() -> void:
	_title.visible = true
	_hud.visible = false
	_win.visible = false
	board.visible = false

	var shop: Button = _title.find_child("Shop", true, false)
	if shop:
		# Sahte magaza uretim derlemesinde HICBIR teklif sunmaz.
		shop.visible = Store.offers_enabled() and not Save.ads_removed
		shop.text = Loc.f("BTN_NO_ADS", [Store.price_of("no_ads")])
	var tema: Button = _title.find_child("ThemeBtn", true, false)
	if tema:
		tema.text = Loc.t("BTN_THEMES")
	var rest: Button = _title.find_child("Restore", true, false)
	if rest:
		rest.visible = not Store.using_stub()
		rest.text = Loc.t("BTN_RESTORE")
	var s: Label = _title.find_child("Stats", true, false)
	if s:
		var n := Save.total_stars()
		var satirlar: Array[String] = []
		if n > 0:
			satirlar.append(Loc.f("LOCKED", [n]))
		# Bir sonraki acilis HEDEFI: "ne kazanacagim" bilgisi, "ne kazandim"
		# bilgisinden daha cok motive ediyor.
		var sonraki := Themes.next_locked(n)
		if not sonraki.is_empty():
			satirlar.append(Loc.f("NEXT_LOOK",
				[int(sonraki.kalan), Loc.t(str(sonraki.tema.ad_key))]))
		s.text = "\n".join(satirlar)


# --------------------------------------------------------------------- akis

func _start_level() -> void:
	_title.visible = false
	_win.visible = false
	_hud.visible = true
	board.visible = true
	_toast.visible = false
	board.load_level(LevelGen.generate(level))
	_lbl_level.text = Loc.f("LEVEL", [level])
	_rehber_kur()
	_on_taps(0)


##
## Ilk bolumde DOKUNULACAK AYNAYI gosteriyoruz.
##
## Fusera'da ilk oyuncu oyunu acti ve "nasil oynaniyor" diye sordu: kural
## ustteki kucuk satirda yaziyordu ama oyuncu tahtaya bakiyor, metne degil.
## Halka dogrudan hedefin uzerinde nabiz gibi atiyor -- yazi okumadan
## anlasiliyor ve her dilde ayni sekilde calisiyor.
##
## Yalnizca BIR KEZ: cozuldugunde bayrak kaydediliyor ve rehber bir daha
## cikmiyor. Her acilista tekrarlanan ogretim, oyunu bilen oyuncu icin en
## hizli birakma sebeplerinden biri.
func _rehber_kur() -> void:
	board.guide = -1
	if Save.taught or level > 1:
		return
	var coz := Solver.solution(board.grid)
	if coz.is_empty():
		return
	board.guide = coz[0]
	_lbl_taps.text = Loc.t("TEACH_TAP")


func _on_taps(t: int) -> void:
	if board.guide >= 0 and t == 0:
		return                              # ogretim satiri yerinde kalsin
	_lbl_taps.text = "%s   %s" % [
		Loc.f("TAPS", [t]), Loc.f("BEST_TAPS", [board.par])]


func _on_solved(taps: int, par: int) -> void:
	var star := Stars.rate(taps, par)
	# Acilis DURUMU kaydetmeden once olculuyor: yildiz eklendikten sonra
	# bakmak "zaten acikti" ile "az once acildi" ayrimini imkansiz kilar.
	var onceki := Themes.by_stars(Save.total_stars()).size()
	if not Save.taught:
		Save.taught = true
	Save.record(level, star)
	var sonraki := Themes.by_stars(Save.total_stars())

	var s: Label = _win.find_child("WinStars", true, false)
	if s:
		s.text = "★".repeat(star) + "☆".repeat(3 - star)
	var d: Label = _win.find_child("WinStats", true, false)
	if d:
		d.text = Loc.f("STATS", [taps, par])
	var mesaj: Label = _win.find_child("WinNote", true, false)
	if mesaj:
		# Yeni tema acildiysa BUNU soyle. Sessizce acmak odul hissini
		# tamamen kaybettiriyor -- oyuncu kazandigini bilmiyor.
		if sonraki.size() > onceki:
			mesaj.text = Loc.t("UNLOCKED")
			mesaj.visible = true
		else:
			mesaj.visible = false

	# Kutlamanin gorulmesi icin kisa bir bekleme; reklam hemen bindirilirse
	# oyuncu kazandigini fark etmeden ekran degisiyor.
	await get_tree().create_timer(0.85).timeout
	Save.levels_since_ad += 1
	await Ads.maybe_show_interstitial(level)
	_win.visible = true
	_hud.visible = false


# ------------------------------------------------------------- kazanma karti

##
## Kart bir PANEL uzerinde duruyor. Metin dogrudan tahtanin ustune binerse
## arkadaki isin ve aynalar okumayi bozuyor. Yari saydam ortu + opak panel,
## gozun nereye bakacagini tartismasiz kiliyor.
func _build_win() -> void:
	_win = Control.new()
	_win.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_win)

	var ortu := ColorRect.new()
	ortu.set_anchors_preset(Control.PRESET_FULL_RECT)
	ortu.color = Color(Palette.BG.r, Palette.BG.g, Palette.BG.b, 0.78)
	_win.add_child(ortu)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -200
	panel.offset_bottom = 200
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.BG_DEEP
	sb.set_corner_radius_all(34)
	sb.border_width_bottom = 8
	sb.border_color = Palette.CARD_EDGE
	sb.shadow_color = Color(0, 0, 0, 0.14)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 34
	sb.content_margin_bottom = 34
	panel.add_theme_stylebox_override("panel", sb)
	_win.add_child(panel)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)

	var st := _label("", 58, Palette.STAR)
	st.name = "WinStars"
	v.add_child(st)
	v.add_child(_label(Loc.t("WIN_TITLE"), 36, Palette.INK))
	var dk := _label("", 24, Palette.INK_SOFT)
	dk.name = "WinStats"
	v.add_child(dk)
	var note := _label("", 24, Palette.ACCENT)
	note.name = "WinNote"
	note.visible = false
	v.add_child(note)

	var nxt := _button(Loc.t("BTN_NEXT"), true)
	nxt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	nxt.pressed.connect(func() -> void:
		Sfx.tap()
		level += 1
		_start_level())
	v.add_child(nxt)


# --------------------------------------------------------------------- temalar

##
## Kilitli temalar da GORUNUYOR, gri ve kac yildiz gerektigi yazili.
## Gizlemek daha temiz durur ama ilerleme hedefini yok eder -- oyuncu neyi
## kazanacagini gormeli.
func _build_themes() -> void:
	_themes = Control.new()
	_themes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_themes.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_themes)

	var ortu := ColorRect.new()
	ortu.set_anchors_preset(Control.PRESET_FULL_RECT)
	ortu.color = Color(Palette.BG.r, Palette.BG.g, Palette.BG.b, 0.9)
	_themes.add_child(ortu)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 60
	v.offset_right = -60
	v.offset_top = 120
	v.offset_bottom = -60
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.name = "List"
	_themes.add_child(v)


func _show_themes() -> void:
	var v: VBoxContainer = _themes.find_child("List", true, false)
	for c in v.get_children():
		c.queue_free()

	var yildiz := Save.total_stars()
	for t in Themes.LIST:
		v.add_child(_theme_row(t, yildiz >= int(t.stars)))

	var kapat := _button(Loc.t("BTN_CLOSE"), true)
	kapat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kapat.pressed.connect(func() -> void:
		Sfx.tap()
		_themes.visible = false
		_title.visible = true)
	v.add_child(kapat)

	# Baslik ekrani GIZLENIYOR: yari saydam ortu arkasindan sizip hayalet
	# metinler birakiyordu ve ekran kirli duruyordu.
	_title.visible = false
	_themes.visible = true


##
## Tek tema satiri: RENK ORNEGI + ad.
##
## Ornek sart. Tema seciminde oyuncunun gormek istedigi sey ismi degil
## rengi; "Okyanus" yazisi hicbir sey anlatmiyor. Uc renk gosteriyoruz --
## zemin, isin, vurgu -- cunku temayi bunlar tanimliyor.
func _theme_row(t: Dictionary, acik: bool) -> Control:
	var kutu := PanelContainer.new()
	kutu.custom_minimum_size = Vector2(0, 86)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.BTN_FACE if acik else Palette.BTN_FACE.lerp(Palette.BG, 0.55)
	sb.set_corner_radius_all(22)
	sb.border_width_bottom = 6 if acik else 2
	sb.border_color = Palette.BTN_EDGE if acik else Palette.BTN_EDGE.lerp(Palette.BG, 0.5)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	kutu.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	kutu.add_child(h)

	var ornek := Control.new()
	ornek.custom_minimum_size = Vector2(112, 44)
	ornek.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ornek.set_script(preload("res://scripts/ui/swatch.gd"))
	ornek.set("renkler", [Color(str(t.bg)), Color(str(t.lit)), Color(str(t.accent))])
	ornek.set("solgun", not acik)
	h.add_child(ornek)

	var ad := Label.new()
	ad.text = Loc.t(str(t.ad_key))
	ad.add_theme_font_size_override("font_size", 28)
	ad.add_theme_color_override("font_color",
		Palette.INK if acik else Palette.INK_SOFT)
	ad.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ad)

	if acik:
		var b := Button.new()
		b.flat = true
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		var id := str(t.id)
		b.pressed.connect(func() -> void:
			Sfx.tap()
			Save.theme = id
			Save.save_data()
			Palette.apply(Themes.find(id))
			# Arayuz rengi KURULURKEN aliyor; tema degisince sahnenin yeniden
			# yuklenmesi sart. Etiketleri tek tek boyamak hem uzun hem
			# unutmaya acik.
			get_tree().reload_current_scene())
		kutu.add_child(b)
	else:
		var kilit := Label.new()
		kilit.text = Loc.f("LOCKED", [int(t.stars)])
		kilit.add_theme_font_size_override("font_size", 22)
		kilit.add_theme_color_override("font_color", Palette.INK_SOFT)
		kilit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(kilit)
	return kutu
