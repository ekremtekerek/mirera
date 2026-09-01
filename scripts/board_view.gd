class_name BoardView
extends Control
##
## Tahtanin cizimi ve dokunus girisi.
##
## Tasarim karari: cizim SIMULASYONUN CIKTISINI boyuyor, kendi hesabini
## yapmiyor. `Grid.trace()` isigin hangi hucreden hangi yone girip ciktigini
## veriyor; burasi yalnizca o adimlari cizgiye ceviriyor. Ikisi ayri
## hesaplansaydi ekranda gorunen isin ile mantigin isledigi isin ayrisabilir
## ve "gozle cozdum ama oyun kabul etmiyor" sinifindan hatalar cikardi.

signal solved(taps: int, par: int)
signal taps_changed(taps: int)

## Isinin yeniden cizilme suresi. Acilista YAVAS: oyuncu isigin yolunu
## izleyerek ne olup bittigini ogreniyor. Dokunustan sonra HIZLI: burada
## bilgi zaten biliniyor, beklemek can sikici olur.
const REVEAL_LOAD := 0.55
const REVEAL_TAP := 0.16

const SPARK_COUNT := 16

var grid: Grid = null
var par := 1
var taps := 0

## Ilk seviyede dokunulacak aynayi gosteren halka. -1 kapali.
##
## Ilk oyuncu Fusera'yi acip "nasil oynaniyor" diye sormustu: kural ustteki
## kucuk satirda yaziyordu ama oyuncu tahtaya bakiyor, metne degil. O yuzden
## ogretim tahtanin UZERINDE, dokunulacak yerin kendisinde duruyor.
var guide := -1
## Odullu reklamdan gelen ipucu: cozume goturen aynalardan biri.
var hint := -1

var _cell := 64.0
var _origin := Vector2.ZERO
var _steps: Array = []
var _ilk_durum := PackedInt32Array()
var _reveal := 1.0
var _reveal_hiz := 4.0
var _clock := 0.0
var _bitti := false
var _win_t := 0.0
var _panel := StyleBoxFlat.new()


class Spark:
	var pos: Vector2
	var vel: Vector2
	var life := 1.0
	var boy: float

var _sparks: Array[Spark] = []


func _ready() -> void:
	set_process(true)


# -------------------------------------------------------------- seviye

func load_level(data: Dictionary) -> void:
	grid = (data.grid as Grid).clone()
	par = int(data.par)
	taps = 0
	_bitti = false
	_win_t = 0.0
	_sparks.clear()
	hint = -1
	_ilk_durum = grid.state.duplicate()
	_relayout()
	_yeniden_ciz(REVEAL_LOAD)
	taps_changed.emit(taps)


##
## Basa don. Dokunus sayaci da sifirlaniyor -- aksi halde "sifirla" tusu
## yildizi kurtarmanin bedava yolu olurdu ve par olcusu anlamini yitirirdi.
func reset_level() -> void:
	if grid == null:
		return
	grid.state = _ilk_durum.duplicate()
	taps = 0
	_bitti = false
	_win_t = 0.0
	_sparks.clear()
	_yeniden_ciz(REVEAL_TAP)
	taps_changed.emit(taps)


func _yeniden_ciz(sure: float) -> void:
	_steps = grid.trace().steps if grid != null else []
	_reveal = 0.0
	_reveal_hiz = 1.0 / maxf(0.05, sure)
	queue_redraw()


func _relayout() -> void:
	if grid == null:
		return
	# Tahta her zaman ekrana SIGACAK sekilde olceklenip ortalaniyor; sabit
	# hucre boyutu 7x7 tahtada tasiyordu.
	var pad := 30.0
	var avail := size - Vector2(pad, pad) * 2.0
	_cell = minf(avail.x / grid.w, avail.y / grid.h)
	var span := Vector2(grid.w, grid.h) * _cell
	_origin = (size - span) * 0.5
	# Panel her karede degil, olcu degisince kuruluyor: StyleBoxFlat uretmek
	# `_draw()` icinde yapilacak bir is degil.
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Palette.BG_DEEP
	_panel.set_corner_radius_all(int(_cell * 0.24))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()
		queue_redraw()


# --------------------------------------------------------------- giris

func _gui_input(event: InputEvent) -> void:
	# TEK dokunus IKI olay uretiyor.
	#
	# Android'de emulate_mouse_from_touch acik (varsayilan): parmak once bir
	# InputEventScreenTouch, ardindan SAHTE bir InputEventMouseButton
	# gonderiyor. Ikisini de islersek ayna iki kez donuyor, yani hic donmemis
	# gibi gorunuyor -- Fusera'da oyuncunun bildirdigi ariza tam olarak buydu
	# ve masaustunde GORUNMUYOR cunku orada yalnizca fare olayi var.
	#
	# Sahte olaylarin cihaz kimligi DEVICE_ID_EMULATION (-1). Gercek fareyi
	# kabul edip sahtesini eliyoruz.
	var basma: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION)
	if not basma:
		return
	if grid == null or _bitti:
		return
	_tap(event.position)


func _tap(pos: Vector2) -> void:
	var yerel := pos - _origin
	var gx := int(floor(yerel.x / _cell))
	var gy := int(floor(yerel.y / _cell))
	if not grid.inside(gx, gy):
		return
	var i := grid.idx(gx, gy)
	if grid.kind[i] != Grid.MIRROR:
		return

	grid.toggle(i)
	taps += 1
	guide = -1
	if hint == i:
		hint = -1
	Sfx.tap()
	_yeniden_ciz(REVEAL_TAP)
	taps_changed.emit(taps)

	if grid.is_solved():
		_kazandi()


func _kazandi() -> void:
	_bitti = true
	_win_t = 0.0
	Sfx.win()
	for i in grid.kind.size():
		if grid.kind[i] == Grid.TARGET:
			_kivilcim(_center(i))
	solved.emit(taps, par)


## Odullu reklam odulu: cozume goturen aynalardan BIRI isaretleniyor.
## Tam cozumu gostermek odulu anlamsizlastirirdi; tek dogru hamle oyuncuyu
## tikandigi yerden cikariyor, gerisini yine kendisi buluyor.
func mark_hint() -> bool:
	if grid == null or _bitti:
		return false
	var coz := Solver.solution(grid)
	if coz.is_empty():
		return false
	hint = coz[0]
	queue_redraw()
	return true


# ----------------------------------------------------------- animasyon

func _process(delta: float) -> void:
	_clock += delta
	var degisti := false
	if _reveal < 1.0:
		_reveal = minf(1.0, _reveal + delta * _reveal_hiz)
		degisti = true
	if _bitti and _win_t < 1.0:
		_win_t = minf(1.0, _win_t + delta * 1.6)
		degisti = true
	if not _sparks.is_empty():
		_kivilcim_guncelle(delta)
		degisti = true
	# Isik akisi ve hedef nabzi surekli donuyor; tahta gorunurken her karede
	# yeniden ciziliyor. Statik bir tahta olu gorunuyordu.
	if visible and grid != null:
		degisti = true
	if degisti:
		queue_redraw()


func _kivilcim(c: Vector2) -> void:
	for i in SPARK_COUNT:
		var s := Spark.new()
		var a := TAU * float(i) / float(SPARK_COUNT) + randf() * 0.3
		s.pos = c
		s.vel = Vector2(cos(a), sin(a)) * _cell * randf_range(1.6, 3.4)
		s.boy = _cell * randf_range(0.05, 0.10)
		s.life = 1.0
		_sparks.append(s)


func _kivilcim_guncelle(delta: float) -> void:
	var kalan: Array[Spark] = []
	for s in _sparks:
		s.life -= delta * 1.5
		if s.life <= 0.0:
			continue
		s.pos += s.vel * delta
		s.vel *= 1.0 - delta * 3.2
		kalan.append(s)
	_sparks = kalan


# ---------------------------------------------------------------- cizim

func _draw() -> void:
	if grid == null:
		return
	_draw_zemin()
	_draw_tiles()
	_draw_isin()
	_draw_isaretler()
	_draw_kivilcim()


func _center(i: int) -> Vector2:
	return _origin + Vector2(grid.cx(i) + 0.5, grid.cy(i) + 0.5) * _cell


## Hucre kenarinin orta noktasi. Isin bir hucreye `d` yonunde girerken
## KARSI kenardan girdigi icin cagri noktalari yonu ters cevirip veriyor.
func _kenar(c: Vector2, d: int) -> Vector2:
	return c + Vector2(Grid.DX[d], Grid.DY[d]) * (_cell * 0.5)


func _draw_zemin() -> void:
	var span := Vector2(grid.w, grid.h) * _cell
	# Pay, ISININ HALESI kadar genis. Tahtadan disari kacan isin kenarda
	# kesiliyor ama halesi devam ediyor; dar bir payla hale panelin disina
	# tasip cizim hatasi gibi gorunuyordu. Oysa kacan isin anlamli bir
	# durum: oyuncuya "buradan disari cikti" diyor.
	var r := Rect2(_origin, span).grow(_cell * 0.30)
	draw_style_box(_panel, r)
	# Izgara cizgileri SOLUK: hucre sinirini gostermeleri yeterli, tahtayi
	# defter kagidina cevirmemeleri gerekiyor.
	var g := Color(Palette.GRID, 0.55)
	for x in range(1, grid.w):
		var px := _origin.x + x * _cell
		draw_line(Vector2(px, _origin.y), Vector2(px, _origin.y + span.y), g, 1.5)
	for y in range(1, grid.h):
		var py := _origin.y + y * _cell
		draw_line(Vector2(_origin.x, py), Vector2(_origin.x + span.x, py), g, 1.5)


func _draw_tiles() -> void:
	var vurulan: Dictionary = {}
	if not _steps.is_empty():
		for s in _steps:
			if grid.kind[int(s.cell)] == Grid.TARGET:
				vurulan[int(s.cell)] = true
	for i in grid.kind.size():
		var c := _center(i)
		match grid.kind[i]:
			Grid.WALL:
				_draw_wall(c)
			Grid.MIRROR:
				_draw_mirror(c, grid.state[i])
			Grid.SPLIT:
				_draw_split(c, grid.state[i])
			Grid.SOURCE:
				_draw_source(c, grid.state[i])
			Grid.TARGET:
				_draw_target(c, vurulan.has(i))


func _draw_wall(c: Vector2) -> void:
	var r := _cell * 0.34
	var kutu := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	draw_rect(kutu.grow(-1.0).abs(), Palette.WALL.darkened(0.22), true)
	draw_rect(Rect2(kutu.position, kutu.size - Vector2(0, r * 0.22)),
		Palette.WALL, true)


##
## Ayna: capraz bir cubuk.
##
## Koseden koseye cizgi, yonelimi TEK BAKISTA okutuyor -- "/" ve "\" ayrimi
## icin ikon ya da ok gerekmiyor. Cubugun altina koyu bir kopyasi konuyor,
## boylece tahtadan yukseliyor gibi duruyor; duz bir cizgi izgaraya
## yapisiyordu ve dokunulabilir oldugu anlasilmiyordu.
func _draw_mirror(c: Vector2, orient: int) -> void:
	var yari := _cell * 0.33
	var a: Vector2
	var b: Vector2
	if orient == 0:                                   # "/"
		a = c + Vector2(-yari, yari)
		b = c + Vector2(yari, -yari)
	else:                                             # "\"
		a = c + Vector2(-yari, -yari)
		b = c + Vector2(yari, yari)
	var kalin := _cell * 0.17
	var golge := Vector2(0, kalin * 0.42)
	_kalin_cizgi(a + golge, b + golge, Palette.MIRROR_EDGE.darkened(0.35), kalin)
	_kalin_cizgi(a, b, Palette.MIRROR_EDGE, kalin)
	_kalin_cizgi(a, b, Palette.MIRROR, kalin * 0.52)
	# Ince beyaz cizik: cilali yuzey okumasi.
	_kalin_cizgi(a.lerp(b, 0.18), a.lerp(b, 0.82),
		Color(Palette.CORE, 0.55), kalin * 0.16)


##
## Bolucu: isini ikiye ayiran prizma. Aynadan AYIRT EDILEBILIR olmasi sart,
## yoksa oyuncu neden iki kol ciktigini anlamiyor. Ayrim iki eksende birden:
## cubuk PARCALI ve yari saydam -- yalnizca renk degistirmek renk korlugu
## olan oyuncuda kayboluyor.
func _draw_split(c: Vector2, orient: int) -> void:
	var yari := _cell * 0.33
	var a: Vector2
	var b: Vector2
	if orient == 0:
		a = c + Vector2(-yari, yari)
		b = c + Vector2(yari, -yari)
	else:
		a = c + Vector2(-yari, -yari)
		b = c + Vector2(yari, yari)
	var kalin := _cell * 0.15
	var renk := Color(Palette.MIRROR, 0.55)
	_kalin_cizgi(a, a.lerp(b, 0.36), renk, kalin)
	_kalin_cizgi(a.lerp(b, 0.64), b, renk, kalin)
	draw_circle(c, kalin * 0.62, Color(Palette.CORE, 0.35))
	draw_arc(c, kalin * 0.62, 0, TAU, 20, Color(Palette.MIRROR, 0.9), 2.0, true)


##
## Kaynak: isigin dogdugu blok. Cikis agzi HANGI YONE baktigi gorulsun diye
## govdenin disina tasiyor -- yon bilgisi olmadan tahtanin okunmasi mumkun
## degil ve bunu bir okla anlatmak metin gerektirirdi.
func _draw_source(c: Vector2, d: int) -> void:
	var r := _cell * 0.30
	var kutu := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	draw_rect(Rect2(kutu.position + Vector2(0, r * 0.18), kutu.size),
		Palette.DIM_DEEP.darkened(0.25), true)
	draw_rect(kutu, Palette.DIM_DEEP, true)
	var agiz := c + Vector2(Grid.DX[d], Grid.DY[d]) * r * 0.92
	var nabiz := 0.80 + 0.20 * sin(_clock * 3.4)
	draw_circle(agiz, r * 0.52 * nabiz, Color(Palette.GLOW, 0.35))
	draw_circle(agiz, r * 0.32, Palette.BEAM)
	draw_circle(agiz, r * 0.16, Palette.CORE)


##
## Hedef: halka. Sonuk ve yanan hal IKI EKSENDE birden ayrisiyor --
## parlaklik ve dolgu. Yalnizca renkle ayirmak renk korlugu olan oyuncuda
## kayboluyor; bu kural her temada korunmali.
func _draw_target(c: Vector2, yanik: bool) -> void:
	var r := _cell * 0.30
	if not yanik:
		# Sonuk halde bile ZAYIF bir hale var. Sebebi tamamen okunabilirlik:
		# halkanin rengi temanin sakin paletinden geliyor ve tahtadaki diger
		# sakin unsurlarla (duvar, kaynak govdesi) karisiyordu -- oyuncu
		# hedefi aramak zorunda kaliyordu. Isik renginden gelen soluk bir
		# hale, halkayi "isigin gidecegi yer" olarak isaretliyor.
		draw_circle(c, r * 1.35, Color(Palette.GLOW, 0.07))
		draw_arc(c, r, 0, TAU, 32, Palette.DIM, _cell * 0.075, true)
		draw_arc(c, r * 0.52, 0, TAU, 24, Palette.RING, _cell * 0.045, true)
		return
	var nabiz := 0.90 + 0.10 * sin(_clock * 5.0)
	draw_circle(c, r * 1.85 * nabiz, Color(Palette.GLOW, 0.13))
	draw_circle(c, r * 1.25 * nabiz, Color(Palette.GLOW, 0.20))
	draw_arc(c, r, 0, TAU, 32, Palette.BEAM, _cell * 0.085, true)
	draw_circle(c, r * 0.62, Palette.BEAM)
	draw_circle(c, r * 0.34, Palette.CORE)


##
## Isin. Dort gecis ust uste: genis ve sonuk hale, orta hale, govde, sicak
## cekirdek. Tek kalin cizgi "isik" degil "boru" gibi gorunuyordu; parlamayi
## yaratan sey ust uste binen saydam katmanlar.
func _draw_isin() -> void:
	if _steps.is_empty():
		return
	var toplam := float(_steps.size())
	var acik := _reveal * toplam
	for i in _steps.size():
		var f := clampf(acik - float(i), 0.0, 1.0)
		if f <= 0.0:
			break
		var p := _adim_noktalari(_steps[i])
		if f < 1.0:
			p = _kismi(p, f)
		if p.size() < 2:
			continue
		# Isigin AKTIGI hissi: cekirdek parlakligi adim numarasina gore
		# dalgalaniyor, yani parlaklik kaynaktan hedefe dogru yuruyor.
		var akis := 0.78 + 0.22 * sin(_clock * 5.5 - float(i) * 0.7)
		_polyline(p, Color(Palette.GLOW, 0.10), _cell * 0.46)
		_polyline(p, Color(Palette.GLOW, 0.22), _cell * 0.24)
		_polyline(p, Color(Palette.BEAM, 0.95), _cell * 0.090)
		_polyline(p, Color(Palette.CORE, akis), _cell * 0.034)


func _adim_noktalari(s: Dictionary) -> PackedVector2Array:
	var c := _center(int(s.cell))
	var p := PackedVector2Array()
	var gir := int(s["in"])
	var cik := int(s["out"])
	if gir >= 0:
		# Isin `gir` yonunde ilerliyor, yani hucreye KARSI kenardan giriyor.
		p.append(_kenar(c, (gir + 2) % 4))
	p.append(c)
	if cik >= 0:
		p.append(_kenar(c, cik))
	return p


## Cok parcali cizginin ilk `f` orani. Isinin ilerleyerek cizilmesi bunun
## uzerine kurulu.
func _kismi(p: PackedVector2Array, f: float) -> PackedVector2Array:
	if p.size() < 2:
		return p
	var toplam := 0.0
	for i in range(1, p.size()):
		toplam += p[i - 1].distance_to(p[i])
	var hedef := toplam * f
	var out := PackedVector2Array([p[0]])
	var gecen := 0.0
	for i in range(1, p.size()):
		var boy := p[i - 1].distance_to(p[i])
		if gecen + boy >= hedef:
			out.append(p[i - 1].lerp(p[i], (hedef - gecen) / maxf(0.001, boy)))
			return out
		gecen += boy
		out.append(p[i])
	return out


func _polyline(p: PackedVector2Array, renk: Color, kalin: float) -> void:
	for i in range(1, p.size()):
		_kalin_cizgi(p[i - 1], p[i], renk, kalin)


## Yuvarlak uclu kalin cizgi. Godot'nun `draw_line` ucu kare biraktigi icin
## kirik noktalarda centik olusuyordu; uclara daire koyunca kayboluyor.
func _kalin_cizgi(a: Vector2, b: Vector2, renk: Color, kalin: float) -> void:
	draw_line(a, b, renk, kalin, true)
	draw_circle(a, kalin * 0.5, renk)
	draw_circle(b, kalin * 0.5, renk)


func _draw_isaretler() -> void:
	if guide >= 0:
		_halka(_center(guide), Palette.ACCENT, 0.0)
	if hint >= 0:
		_halka(_center(hint), Palette.ACCENT, 0.5)


## Nabiz atan halka. Buyuyup soluyor: durgun bir cerceve gozden kaciyordu.
func _halka(c: Vector2, renk: Color, faz: float) -> void:
	var t := fmod(_clock * 0.9 + faz, 1.0)
	var r := _cell * (0.36 + 0.16 * t)
	draw_arc(c, r, 0, TAU, 36, Color(renk, (1.0 - t) * 0.85), _cell * 0.05, true)


func _draw_kivilcim() -> void:
	for s in _sparks:
		var a := clampf(s.life, 0.0, 1.0)
		draw_circle(s.pos, s.boy * a, Color(Palette.SPARK, a))
