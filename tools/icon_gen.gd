extends Node
##
## Uygulama ikonu ve magaza gorselleri uretir.
##
##   godot --path . -- icon
##   godot --path . -- icon tr        (one cikan gorseli o dilde uretir)
##
## Ikon MEKANIGI anlatmali: kaynaktan cikan bir isin, iki aynada kirilip
## hedefe variyor. Soyut bir amblem yerine oyunun kendi dilini kullanmak,
## magaza listesinde ne oynayacagini bir bakista anlatiyor -- ve ayni sekil
## baslik ekranindaki amblemle birebir ayni, yani marka tutarli.
##
## Kucuk boyutta okunabilirlik icin: uc yandan kapali TEK bir yol, kalin
## cizgi, yuksek kontrast. 48 pikselde geriye "parlak bir dirsek ve ucunda
## isik" kaliyor ve bu yeterli.

const OUT := "D:/Temp/mirera-icons"

##
## Ikon zemini oyunun krem arka planindan AYRI.
##
## Krem bir kare, magaza izgarasinda ve telefon ana ekraninda komsularinin
## arasinda kayboluyordu. Koyu zemin ikonu "karanlikta bir isin" sahnesine
## cevirip huzmeyi one cikariyor ve acik/koyu her arayuzde ayni duruyor.
## Bir isik oyununda bu zaten dogru olan: isik ancak karanlikta gorulur.
const ICON_BG := Color("#12161d")
const BEAM := Color("#ffb43d")
const BEAM_CORE := Color("#fff6e0")
const GLOW := Color("#ff9c2b")
const CAM := Color("#5ce1e6")            ## ayna: sicak paletten ayrisan tek renk
const CAM_KOYU := Color("#2f7d86")
const GOVDE := Color("#39424f")          ## kaynak blogu
const KENAR := 96.0                      ## one cikan gorselde guvenli bosluk


func _ready() -> void:
	_force_lang()
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().process_frame
	_icon(512, "icon-512.png")
	# 1024 URETILMIYOR: Play 512 istiyor ve piksel piksel cizim 1024 tuvalde
	# dakikalar suruyor. Gerekirse 512 buyutulur.
	_uygulama_ikonlari()
	await _feature()
	print("ICON OK -> ", OUT)
	get_tree().quit()


func _canvas(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(ICON_BG)
	return img


## Godot'un Image API'sinde daire cizimi yok; piksel piksel doldurup KENAR
## YUMUSATMA icin alt piksel orneklemesi yapiyoruz. Sert kenarli daireler
## ikon boyutunda tirtikli duruyor.
func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	var x0 := maxi(0, int(c.x - r) - 1)
	var x1 := mini(img.get_width() - 1, int(c.x + r) + 1)
	var y0 := maxi(0, int(c.y - r) - 1)
	var y1 := mini(img.get_height() - 1, int(c.y + r) + 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var kapsam := 0.0
			for sy in 2:
				for sx in 2:
					var p := Vector2(x + 0.25 + sx * 0.5, y + 0.25 + sy * 0.5)
					if p.distance_to(c) <= r:
						kapsam += 0.25
			if kapsam <= 0.0:
				continue
			var eski := img.get_pixel(x, y)
			img.set_pixel(x, y, eski.lerp(col, kapsam * col.a))


func _glow(img: Image, c: Vector2, r: float, col: Color, guc: float) -> void:
	var x0 := maxi(0, int(c.x - r) - 1)
	var x1 := mini(img.get_width() - 1, int(c.x + r) + 1)
	var y0 := maxi(0, int(c.y - r) - 1)
	var y1 := mini(img.get_height() - 1, int(c.y + r) + 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d >= r:
				continue
			# Ussun 2.4 olmasi: merkezde yogun, kenarda neredeyse yok --
			# dogrusal sonum halenin sinirini gozle secilir birakiyordu.
			var a := pow(1.0 - d / r, 2.4) * guc
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, a))


func _bar(img: Image, a: Vector2, b: Vector2, kalinlik: float, col: Color) -> void:
	var adim := int(a.distance_to(b))
	for i in range(adim + 1):
		_disc(img, a.lerp(b, float(i) / maxf(1.0, adim)), kalinlik * 0.5, col)


func _halka(img: Image, c: Vector2, r: float, kalinlik: float, col: Color) -> void:
	var n := int(TAU * r)
	for i in n:
		var a := TAU * float(i) / float(n)
		_disc(img, c + Vector2(cos(a), sin(a)) * r, kalinlik * 0.5, col)


##
## Isin boyunca hale. Tek tek noktalara hale koymak, huzmenin uzunlugundan
## bagimsiz olarak esit yogunluk veriyor -- tek buyuk hale kisa parcalarda
## tasip uzun parcalarda zayif kaliyordu.
func _huzme_hale(img: Image, a: Vector2, b: Vector2, r: float, guc: float) -> void:
	var adim := maxi(1, int(a.distance_to(b) / (r * 0.35)))
	for i in range(adim + 1):
		_glow(img, a.lerp(b, float(i) / float(adim)), r, GLOW, guc)


##
## Ikonun sekli: kaynak -> saga -> ayna -> yukari -> ayna -> sola -> hedef.
##
## Uc yandan kapali bir yol, kareyi dengeli dolduruyor. Onceki denemede tek
## dirsekli bir "L" vardi ve karenin bir kosesi bos kaliyordu; kare bir
## ikonda bu dengesiz duruyor.
##
## Ayni sekil baslik ekranindaki canli amblemle birebir ayni: oyuncu
## magazada gordugu seyi oyunu acinca hareket ederken buluyor.
func _mark(img: Image, s: float) -> void:
	var sol := s * 0.245
	var sag := s * 0.755
	var ust := s * 0.245
	var alt := s * 0.755
	var kaynak := Vector2(sol, alt)
	var a1 := Vector2(sag, alt)                 # ayna 1
	var a2 := Vector2(sag, ust)                 # ayna 2
	var hedef := Vector2(sol, ust)

	var kalin := s * 0.052
	var cekirdek := s * 0.020
	var hale := s * 0.150

	# Hale EN ALTTA: uzerine cizilirse huzmeyi ve aynalari puslendiriyor.
	_huzme_hale(img, kaynak, a1, hale, 0.55)
	_huzme_hale(img, a1, a2, hale, 0.55)
	_huzme_hale(img, a2, hedef, hale, 0.55)

	# Aynalar huzmenin ALTINDA: isik aynanin yuzunden geciyor gibi okunuyor.
	_ayna(img, a1, s * 0.086, s * 0.040, true)      # "/"
	_ayna(img, a2, s * 0.086, s * 0.040, false)     # "\"

	for p in [[kaynak, a1], [a1, a2], [a2, hedef]]:
		_bar(img, p[0], p[1], kalin, BEAM)
	for p in [[kaynak, a1], [a1, a2], [a2, hedef]]:
		_bar(img, p[0], p[1], cekirdek, BEAM_CORE)

	# Kaynak blogu ve agzi.
	_kare(img, kaynak, s * 0.072, GOVDE)
	_disc(img, kaynak, s * 0.030, BEAM_CORE)

	# Hedef: yanan halka. Ikonun tek "varis" isareti bu, o yuzden en parlak
	# nokta burasi -- 48 pikselde geriye kalan sey de bu.
	_glow(img, hedef, s * 0.200, GLOW, 0.85)
	_halka(img, hedef, s * 0.082, s * 0.030, BEAM)
	_disc(img, hedef, s * 0.040, BEAM_CORE)


func _ayna(img: Image, c: Vector2, yari: float, kalin: float, egik: bool) -> void:
	var a := c + (Vector2(-yari, yari) if egik else Vector2(-yari, -yari))
	var b := c + (Vector2(yari, -yari) if egik else Vector2(yari, yari))
	_bar(img, a, b, kalin, CAM_KOYU)
	_bar(img, a, b, kalin * 0.50, CAM)


func _kare(img: Image, c: Vector2, yari: float, col: Color) -> void:
	for y in range(int(c.y - yari), int(c.y + yari) + 1):
		for x in range(int(c.x - yari), int(c.x + yari) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			img.set_pixel(x, y, col)


func _icon(boy: int, ad: String) -> void:
	var img := _canvas(boy, boy)
	_mark(img, float(boy))
	img.save_png("%s/%s" % [OUT, ad])
	print("  ", ad)


##
## Uygulamanin KENDI ikonlari projenin icine yaziliyor (res://brand/).
## Magaza gorselleri D:/Temp'te kaliyor -- depoya girmelerinin anlami yok;
## bunlar ise derlemeye giriyor, dolayisiyla surumlenmeleri gerekiyor.
##
## Uyarlanabilir ikonda on plan icerigi guvenli bolgede (merkez %66) kalmali,
## yoksa cihaz kirpmasinda kesiliyor -- bu yuzden sekil kucultuluyor.
func _uygulama_ikonlari() -> void:
	var dizin := ProjectSettings.globalize_path("res://brand")
	DirAccess.make_dir_recursive_absolute(dizin)
	for boy in [192, 512]:
		var img := _canvas(boy, boy)
		_mark(img, float(boy))
		img.save_png("%s/icon-%d.png" % [dizin, boy])

	var on := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	on.fill(Color(0, 0, 0, 0))
	# 0.78 olcek: 432'lik tuvalde sekil 337 piksele iniyor, yani guvenli
	# dairenin icinde kaliyor.
	var kucuk := _canvas(337, 337)
	_mark(kucuk, 337.0)
	kucuk.convert(Image.FORMAT_RGBA8)
	# Zemini saydama cevirmek yerine sekli saydam tuvale KOPYALIYORUZ:
	# renk anahtarlama halenin kenarinda kirli bir cerceve birakiyordu.
	var saydam := Image.create(337, 337, false, Image.FORMAT_RGBA8)
	saydam.fill(Color(0, 0, 0, 0))
	_mark(saydam, 337.0)
	on.blend_rect(saydam, Rect2i(0, 0, 337, 337), Vector2i(47, 47))
	on.save_png("%s/adaptive-foreground-432.png" % dizin)

	var arka := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	arka.fill(ICON_BG)
	arka.save_png("%s/adaptive-background-432.png" % dizin)
	print("  uygulama ikonlari -> res://brand")


##
## Magaza "one cikan gorseli" (1024x500).
##
## Metin SAHNEDEN geliyor: Godot'nun Image API'sinde yazi cizimi yok. Saydam
## zeminli kucuk bir SubViewport'a yalnizca yaziyi cizdirip sonucu gorselin
## uzerine harmanliyoruz -- boylece yazi tipi oyunun kendisiyle birebir ayni.
##
## Marka adinin altinda cevrilen bir alt baslik var, dolayisiyla gorsel DILE
## BAGLI: Play Console her dil icin ayri one cikan gorsel kabul ediyor.
func _feature() -> void:
	var img := _canvas(1024, 500)
	# Sekil SAGA alindi, sol yari yaziya birakildi. Google bu gorseli bazi
	# yerlerde kenarlarindan kirpiyor; onemli olan her sey ortada durmali.
	var s := 380.0
	var kaydir := Vector2(596.0, 60.0)
	var kat := Image.create(int(s), int(s), false, Image.FORMAT_RGBA8)
	kat.fill(Color(0, 0, 0, 0))
	_mark(kat, s)
	img.blend_rect(kat, Rect2i(0, 0, int(s), int(s)),
		Vector2i(int(kaydir.x), int(kaydir.y)))

	var yazi := await _text_layer(1024, 500)
	img.blend_rect(yazi, Rect2i(0, 0, 1024, 500), Vector2i(0, 0))
	img.save_png("%s/feature-1024x500-%s.png" % [OUT, Loc.lang])
	print("  ozellik grafigi (%s)" % Loc.lang)


func _text_layer(w: int, h: int) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var ad := Label.new()
	ad.text = "MIRERA"
	ad.add_theme_font_size_override("font_size", 104)
	ad.add_theme_color_override("font_color", BEAM_CORE)
	ad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ad.set_anchors_preset(Control.PRESET_FULL_RECT)
	ad.offset_right = -470                     # sol yariya hizali
	ad.offset_top = 150
	vp.add_child(ad)

	# Alt baslik guvenli genislige SIGDIRILIYOR: uzun ceviriler sabit
	# puntoda kenardan tasiyor ve Google gorseli kenarlarindan kirpiyor.
	var metin := Loc.t("TITLE_TAG")
	var punto := 36
	var yf := ThemeDB.fallback_font
	while punto > 20 and yf.get_string_size(metin, HORIZONTAL_ALIGNMENT_LEFT,
			-1, punto).x > 520.0:
		punto -= 1

	var alt := Label.new()
	alt.text = metin
	alt.add_theme_font_size_override("font_size", punto)
	alt.add_theme_color_override("font_color", BEAM)
	alt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alt.set_anchors_preset(Control.PRESET_FULL_RECT)
	alt.offset_right = -470
	alt.offset_top = 270
	vp.add_child(alt)

	# Iki kare: ilkinde yerlesim hesaplaniyor, ikincisinde ciziliyor.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var cikti := vp.get_texture().get_image()
	vp.queue_free()
	return cikti


func _force_lang() -> void:
	for a in OS.get_cmdline_user_args():
		if a.length() == 2 and Loc.SUPPORTED.has(a):
			Loc.lang = a
