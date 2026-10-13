extends SceneTree
##
##   godot --headless --path . --script res://tests/test_sim.gd
##
## Oyunun butun dogrulugu Grid/Solver/LevelGen ucgeninde. Gorsel katman
## bunlarin ustune oturuyor ve hicbir kural tasimiyor; o yuzden burada
## gecen bir surum, cihazda da ayni sekilde davraniyor.

var checks := 0
var failed := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failed += 1
		print("  BASARISIZ: ", msg)


func _initialize() -> void:
	print("\n=== MIRERA simulasyon testleri ===\n")
	t_yansima()
	t_isin()
	t_dongu()
	t_bolucu()
	t_cozucu()
	t_uretim()
	t_locale()
	t_ad_policy()
	t_store_gate()
	t_urun_karsiligi()
	t_export_safety()
	t_kurulum()
	t_ios_kurulum()
	print("\n%d kontrol, %d hata" % [checks, failed])
	quit(1 if failed > 0 else 0)


##
## Yansima tablosu. Yon numaralarinin sirasi (0=sag 1=asagi 2=sol 3=yukari)
## `3 - d` ve `d ^ 1` formullerinin gecerliligini belirliyor; sira degisirse
## oyun sessizce yanlis calisir, o yuzden tablo burada sabitlenmis durumda.
func t_yansima() -> void:
	print("- yansima")
	# "/" aynasi
	check(Grid.reflect(Grid.YON_SAG, 0) == Grid.YON_YUKARI, "/ sag -> yukari")
	check(Grid.reflect(Grid.YON_YUKARI, 0) == Grid.YON_SAG, "/ yukari -> sag")
	check(Grid.reflect(Grid.YON_SOL, 0) == Grid.YON_ASAGI, "/ sol -> asagi")
	check(Grid.reflect(Grid.YON_ASAGI, 0) == Grid.YON_SOL, "/ asagi -> sol")
	# "\" aynasi
	check(Grid.reflect(Grid.YON_SAG, 1) == Grid.YON_ASAGI, "\\ sag -> asagi")
	check(Grid.reflect(Grid.YON_ASAGI, 1) == Grid.YON_SAG, "\\ asagi -> sag")
	check(Grid.reflect(Grid.YON_SOL, 1) == Grid.YON_YUKARI, "\\ sol -> yukari")
	check(Grid.reflect(Grid.YON_YUKARI, 1) == Grid.YON_SOL, "\\ yukari -> sol")
	# Yansima cift yonlu olmali: ayni aynadan geri giren isik geldigi yoldan doner.
	for d in 4:
		for o in 2:
			check(Grid.reflect(Grid.reflect(d, o), o) == d,
				"yansima tersinir (d=%d o=%d)" % [d, o])
	# orient_for, reflect'in tersi olmali.
	for d in 4:
		for o in 2:
			var nd := Grid.reflect(d, o)
			check(Grid.orient_for(d, nd) == o, "orient_for tutarli (d=%d o=%d)" % [d, o])


## Duz gidis, ayna donusu, duvarda sonlanma, hedefe varis.
func t_isin() -> void:
	print("- isin yayilimi")
	# 3x1: kaynak -> bosluk -> hedef
	var g := Grid.new(3, 1)
	g.kind[0] = Grid.SOURCE
	g.state[0] = Grid.YON_SAG
	g.kind[2] = Grid.TARGET
	check(g.is_solved(), "duz isin hedefe variyor")

	# Duvar isigi keser.
	var d := Grid.new(3, 1)
	d.kind[0] = Grid.SOURCE
	d.state[0] = Grid.YON_SAG
	d.kind[1] = Grid.WALL
	d.kind[2] = Grid.TARGET
	check(not d.is_solved(), "duvar isigi kesiyor")

	# Ayna: saga giden isin "/" ile yukari donuyor.
	var m := Grid.new(2, 2)
	m.kind[m.idx(0, 1)] = Grid.SOURCE
	m.state[m.idx(0, 1)] = Grid.YON_SAG
	m.kind[m.idx(1, 1)] = Grid.MIRROR
	m.state[m.idx(1, 1)] = 0                    # "/"
	m.kind[m.idx(1, 0)] = Grid.TARGET
	check(m.is_solved(), "/ aynasi isigi yukari ceviriyor")
	m.toggle(m.idx(1, 1))                       # "\" -> asagi, tahta disi
	check(not m.is_solved(), "\\ aynasi ayni hedefi vurmuyor")

	# Iz, cizim icin dogru adimlari veriyor mu.
	m.toggle(m.idx(1, 1))
	var iz := m.trace()
	check(iz.solved, "iz de cozulmus diyor")
	var ayna_adim := {}
	for s in iz.steps:
		if s.cell == m.idx(1, 1):
			ayna_adim = s
	check(ayna_adim.get("in", -9) == Grid.YON_SAG
		and ayna_adim.get("out", -9) == Grid.YON_YUKARI,
		"ayna adiminda giris/cikis yonleri dogru")

	# Hedefe varmayan isin: iki hedef varsa ikisi de gerekli.
	var iki := Grid.new(3, 1)
	iki.kind[0] = Grid.SOURCE
	iki.state[0] = Grid.YON_SAG
	iki.kind[1] = Grid.TARGET
	iki.kind[2] = Grid.TARGET
	check(not iki.is_solved(), "hedef isigi yuttugu icin arkadaki hedef yanmiyor")


##
## Sonsuz dongu korumasi.
##
## Yalnizca AYNA varken dongu OLUSAMAZ: her ayna iki bagimsiz kanal
## tasiyor ("/" icin sag<->yukari ve sol<->asagi), yayilim tersinir, yani
## isin ya tahtayi terk eder ya yutulur. Kapali bir halkaya disaridan
## girilemez -- halkayi kullanan kanal doludur, diger kanal halkanin
## disina cikar.
##
## Dongu ancak BOLUCU ile mumkun: bolucu isini cogalttigi icin tersinirlik
## bozuluyor. Asagidaki tahta tam olarak boyle bir halka kuruyor ve
## `(hucre, yon)` korumasi olmasa oyun burada kilitlenirdi.
func t_dongu() -> void:
	print("- sonsuz dongu korumasi")
	var g := Grid.new(5, 5)
	g.kind[g.idx(0, 1)] = Grid.SOURCE
	g.state[g.idx(0, 1)] = Grid.YON_SAG
	g.kind[g.idx(1, 1)] = Grid.SPLIT
	g.state[g.idx(1, 1)] = 0                     # "/"
	g.kind[g.idx(3, 1)] = Grid.MIRROR
	g.state[g.idx(3, 1)] = 1                     # sag -> asagi
	g.kind[g.idx(3, 3)] = Grid.MIRROR
	g.state[g.idx(3, 3)] = 0                     # asagi -> sol
	g.kind[g.idx(1, 3)] = Grid.MIRROR
	g.state[g.idx(1, 3)] = 1                     # sol -> yukari, halka kapaniyor
	# Buraya donmek zaten korumanin calistigini kanitliyor: koruma olmasa
	# `_yuru` hic donmezdi.
	var iz := g.trace()
	check(iz.steps.size() < 200, "halka sonlaniyor (%d adim)" % iz.steps.size())
	check(not iz.solved, "hedefsiz tahtada cozulmus denmiyor")


## Bolucu isini ikiye ayirip iki hedefi birden vuruyor mu.
func t_bolucu() -> void:
	print("- bolucu")
	var g := Grid.new(3, 3)
	g.kind[g.idx(0, 1)] = Grid.SOURCE
	g.state[g.idx(0, 1)] = Grid.YON_SAG
	g.kind[g.idx(1, 1)] = Grid.SPLIT
	g.state[g.idx(1, 1)] = 0                     # "/" -> sag'dan yukari + duz
	g.kind[g.idx(1, 0)] = Grid.TARGET            # yansiyan kol
	g.kind[g.idx(2, 1)] = Grid.TARGET            # duz devam eden kol
	check(g.is_solved(), "bolucu iki hedefi birden vuruyor")
	check(g.mirrors().is_empty(), "bolucu dokunulabilir ayna sayilmiyor")


func t_cozucu() -> void:
	print("- cozucu")
	# Zaten cozulmus tahta: 0 dokunus.
	var c := Grid.new(3, 1)
	c.kind[0] = Grid.SOURCE
	c.state[0] = Grid.YON_SAG
	c.kind[2] = Grid.TARGET
	check(Solver.par(c) == 0, "cozulmus tahta 0 dokunus")

	# Tek ters ayna: 1 dokunus.
	var g := Grid.new(2, 2)
	g.kind[g.idx(0, 1)] = Grid.SOURCE
	g.state[g.idx(0, 1)] = Grid.YON_SAG
	g.kind[g.idx(1, 1)] = Grid.MIRROR
	g.state[g.idx(1, 1)] = 1                     # ters
	g.kind[g.idx(1, 0)] = Grid.TARGET
	check(Solver.par(g) == 1, "tek ters ayna 1 dokunus")
	var coz := Solver.solution(g)
	check(coz.size() == 1 and coz[0] == g.idx(1, 1), "cozum dogru aynayi gosteriyor")

	# Cozumsuz tahta: -1.
	var y := Grid.new(3, 1)
	y.kind[0] = Grid.SOURCE
	y.state[0] = Grid.YON_SAG
	y.kind[1] = Grid.WALL
	y.kind[2] = Grid.TARGET
	check(Solver.par(y) == -1, "duvar arkasindaki hedef cozumsuz")

	# Iki ayna, ikisi de ters: 2 dokunus.
	var i := Grid.new(3, 3)
	i.kind[i.idx(0, 2)] = Grid.SOURCE
	i.state[i.idx(0, 2)] = Grid.YON_SAG
	i.kind[i.idx(2, 2)] = Grid.MIRROR
	i.state[i.idx(2, 2)] = 1                     # dogrusu "/" (sag->yukari)
	i.kind[i.idx(2, 0)] = Grid.MIRROR
	i.state[i.idx(2, 0)] = 0                     # dogrusu "\" (yukari->sol)
	i.kind[i.idx(0, 0)] = Grid.TARGET
	check(Solver.par(i) == 2, "iki ters ayna 2 dokunus (%d)" % Solver.par(i))


##
## Uretim: 1..90 arasi HER seviye cozulebilir, bandinda ve DETERMINIST
## olmali. Bu test, oyunun tek gercek soz verdigi seyi kontrol ediyor --
## oyuncunun onune cozulemeyecek bir tahta cikmayacak.
func t_uretim() -> void:
	print("- uretim")
	var toplam_par := 0
	for lv in range(1, 91):
		var r := LevelGen.generate(lv)
		var g: Grid = r.grid
		var cfg: Dictionary = r.cfg
		var p: int = r.par

		check(p >= 1, "seviye %d cozulebilir ve acilista cozulmemis (par=%d)" % [lv, p])
		check(Solver.par(g, 8) == p, "seviye %d par degeri tutarli" % lv)
		check(not g.is_solved(), "seviye %d acilista cozulmus degil" % lv)
		check(g.target_count() >= 1, "seviye %d hedefi var" % lv)
		check(g.mirrors().size() >= 1, "seviye %d dokunulabilir aynasi var" % lv)
		check(g.w == cfg.w and g.h == cfg.h, "seviye %d tahta boyu ayarla uyuyor" % lv)

		# Cozum uygulaninca gercekten cozulmeli -- ipucu bunu kullaniyor.
		var coz := Solver.solution(g)
		check(coz.size() == p, "seviye %d cozum boyu par ile ayni" % lv)
		var k := g.clone()
		for c in coz:
			k.toggle(c)
		check(k.is_solved(), "seviye %d cozumu uygulaninca cozuluyor" % lv)

		toplam_par += p

	# Determinizm: ayni seviye iki kez uretilince ayni tahta cikmali.
	# Yildizlar seviyeye gore kaydediliyor; tahta degisirse kayit yalan olur.
	for lv in [1, 7, 23, 44, 77]:
		var a: Grid = LevelGen.generate(lv).grid
		var b: Grid = LevelGen.generate(lv).grid
		check(a.kind == b.kind and a.state == b.state,
			"seviye %d determinist" % lv)

	# Ilk uc seviye TEK dokunus olmali: oyunun ogretici kismi bu.
	for lv in [1, 2, 3]:
		check(LevelGen.generate(lv).par == 1, "seviye %d tek dokunusluk" % lv)

	print("  ortalama par: %.2f" % (float(toplam_par) / 90.0))


func t_locale() -> void:
	print("- ceviri tablosu")
	var fa := FileAccess.open("res://locale/mirera.csv", FileAccess.READ)
	check(fa != null, "tablo acilabiliyor")
	if fa == null:
		return
	var head := fa.get_csv_line()
	var diller: Array = Array(head).slice(1)
	for kod in Loc.SUPPORTED:
		check(diller.has(kod), "%s dili tabloda var" % kod)

	var anahtarlar := {}
	var en_uzun := {}
	while not fa.eof_reached():
		var row := fa.get_csv_line()
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		var key: String = row[0]
		check(not anahtarlar.has(key), "anahtar tekrar etmiyor: %s" % key)
		check(row.size() == head.size(),
			"%s: %d sutun bekleniyordu, %d var" % [key, head.size(), row.size()])
		var en_ph := _ph(row[1])
		for i in range(1, mini(row.size(), head.size())):
			var metin: String = row[i]
			var dil: String = diller[i - 1]
			check(metin.strip_edges() != "", "%s / %s bos degil" % [key, dil])
			check(_ph(metin) == en_ph,
				"%s / %s yer tutucu sayisi ingilizceyle ayni" % [key, dil])
			var u: int = en_uzun.get(dil, 0)
			en_uzun[dil] = maxi(u, metin.length())
		anahtarlar[key] = true
	fa.close()
	check(anahtarlar.size() >= 10, "beklenen sayida anahtar (%d)" % anahtarlar.size())

	var uzunlar: Array = []
	for dil in en_uzun.keys():
		if int(en_uzun[dil]) > 34:
			uzunlar.append("%s:%d" % [dil, en_uzun[dil]])
	print("  en uzun metinler: ", "yok" if uzunlar.is_empty() else ", ".join(uzunlar))


static func _ph(s: String) -> int:
	var n := 0
	for i in 4:
		if s.contains("{%d}" % i):
			n += 1
	return n


func t_ad_policy() -> void:
	print("- reklam politikasi")
	var temel := {
		"level": 20, "levels_since_ad": 5, "seconds_since_ad": 300.0,
		"seconds_since_reward": 9999.0, "ads_removed": false,
	}
	check(AdPolicy.should_show_interstitial(temel), "normal kosulda gosteriliyor")

	var erken := temel.duplicate(); erken.level = 5
	check(not AdPolicy.should_show_interstitial(erken), "ilk on seviye reklamsiz")

	var yakin := temel.duplicate(); yakin.seconds_since_ad = 10.0
	check(not AdPolicy.should_show_interstitial(yakin), "cok yakin reklam gosterilmiyor")

	var odul := temel.duplicate(); odul.seconds_since_reward = 5.0
	check(not AdPolicy.should_show_interstitial(odul), "odul sonrasi bekleme var")

	var alinmis := temel.duplicate(); alinmis.ads_removed = true
	check(not AdPolicy.should_show_interstitial(alinmis), "reklamsiz satin alma kapatir")

	# Kapi UC sarta bakiyor: iki birim kimligi VE uygulama kimligi.
	# Ucuncusu Mirera 1.0.1 yayina cikip sifir kazandiktan sonra eklendi:
	# app_id bos kalirsa eklenti manifest'e Google'in TEST uygulama
	# kimligini yaziyor ve birimler dogru olsa bile istek gelmiyor.
	var app_id := str(ProjectSettings.get_setting("admob/general/android/app_id", ""))
	check(AdMobAdProvider.canli_birimler_hazir()
		== (AdMobAdProvider.LIVE_INTERSTITIAL != ""
			and AdMobAdProvider.LIVE_REWARDED != ""
			and app_id != "" and app_id != AdMobAdProvider.TEST_APP_ID),
		"canli birim kapisi iki birimi VE uygulama kimligini ariyor")
	if AdMobAdProvider.LIVE_INTERSTITIAL != "" or AdMobAdProvider.LIVE_REWARDED != "":
		check(app_id != "" and app_id != AdMobAdProvider.TEST_APP_ID,
			"canli birim doluysa uygulama kimligi de gercek")
	if not AdMobAdProvider.canli_birimler_hazir():
		print("  NOT: canli reklam birimleri henuz bos -- AdMob uygulamasi acilinca doldurulacak")


func t_store_gate() -> void:
	print("- satin alma kapisi")
	var S = load("res://scripts/store/store_service.gd")
	check(not S.offers_allowed(true, true), "sahte magaza uretimde teklif SUNMAZ")
	check(S.offers_allowed(true, false), "sahte magaza testte teklif sunar")
	check(S.offers_allowed(false, true), "gercek Billing uretimde sunar")
	check(S.offers_allowed(false, false), "gercek Billing testte sunar")


##
## Disa aktarim guvenligi. Yaninda `.import` olan dosya PAKETE GIRMIYOR:
## `FileAccess` duzenleyicide calisiyor, APK icinde null donuyor. Fusera'da
## ceviri tablosu tam olarak boyle kaybolmustu.
func t_export_safety() -> void:
	print("- disa aktarim guvenligi")
	var acilanlar := _fileaccess_yollari(["res://scripts", "res://tools"])
	for yol in acilanlar:
		check(not FileAccess.file_exists(yol + ".import"),
			"FileAccess ile acilan %s pakete girmiyor" % yol)

	var anahtarlar := _csv_anahtarlari()
	check(anahtarlar.size() >= 10, "CSV'den anahtar okundu (%d)" % anahtarlar.size())
	for kod in Loc.SUPPORTED:
		var c: Translation = ResourceLoader.load(
			"res://locale/mirera.%s.translation" % kod) as Translation
		check(c != null, "%s cevirisi kaynak olarak yuklenebiliyor" % kod)
		if c == null:
			continue
		var eksik: Array = []
		for k in anahtarlar:
			if String(c.get_message(k)) == "":
				eksik.append(k)
		check(eksik.is_empty(), "%s: cevrilmemis anahtar yok (%s)"
			% [kod, ", ".join(eksik.slice(0, 3))])


func _fileaccess_yollari(kokler: Array) -> Array:
	var re := RegEx.create_from_string(
		r'FileAccess\.(?:open|get_file_as_string|get_file_as_bytes)\(\s*"(res://[^"]+)"')
	var bulunan := []
	var kuyruk := kokler.duplicate()
	while not kuyruk.is_empty():
		var d: String = kuyruk.pop_back()
		for ad in DirAccess.get_directories_at(d):
			kuyruk.append("%s/%s" % [d, ad])
		for ad in DirAccess.get_files_at(d):
			if not ad.ends_with(".gd"):
				continue
			# Yorum satirlari ATILIYOR: bu dosyalarin aciklamalari da ornek
			# olarak res:// yolu iceriyor.
			var kod := ""
			for satir in FileAccess.get_file_as_string(
					"%s/%s" % [d, ad]).split("\n"):
				if not satir.strip_edges().begins_with("#"):
					kod += satir + "\n"
			for m in re.search_all(kod):
				var yol := m.get_string(1)
				if not bulunan.has(yol):
					bulunan.append(yol)
	return bulunan


func _csv_anahtarlari() -> Array:
	var fa := FileAccess.open("res://locale/mirera.csv", FileAccess.READ)
	if fa == null:
		return []
	fa.get_csv_line()
	var k := []
	while not fa.eof_reached():
		var row := fa.get_csv_line()
		if row.size() >= 2 and row[0].strip_edges() != "":
			k.append(row[0])
	fa.close()
	return k


##
## KURULUM DENETIMI.
##
## Buradaki her satir, YASANMIS ve SESSIZ bir arizanin karsiligi. Ortak
## ozellikleri sunlar: oyun derleniyor, aciliyor, oynaniyor -- ve tek bir
## hata mesaji vermeden yanlis calisiyor. Hicbiri oynayarak fark
## edilemiyor, cogu ancak magazada ya da AdMob panosunda haftalar sonra
## goruluyor.
##
## O yuzden denetim bir kontrol listesi degil, TEST. Kontrol listesi
## unutuluyor; test dusuyor.
func t_kurulum() -> void:
	print("- kurulum denetimi")

	# 1) EKRAN YONU. `handheld/orientation` bir TAM SAYI enum: 0=YATAY
	# (varsayilan), 1=DIKEY. Metin ("portrait") yazilirsa sessizce yok
	# sayiliyor ve oyun telefonda yatay aciliyor. Fusera'da bu ancak
	# cihazda fark edildi.
	check(int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)) == 1,
		"ekran yonu DIKEY (tam sayi 1)")

	# 2) ETC2/ASTC olmadan Android disa aktarimi dokulari reddediyor.
	check(bool(ProjectSettings.get_setting(
		"rendering/textures/vram_compression/import_etc2_astc", false)),
		"ETC2/ASTC doku sikistirmasi acik")

	# 3) EKLENTI KAYDI. `project.godot` bir ConfigFile ve yorum karakteri
	# TEK noktali virgul. `##` ile yorum yazilirsa Godot bolum basliklarini
	# ayristiramiyor, [editor_plugins] sessizce kayboluyor ve reklam +
	# satin alma derlemeye HIC girmiyor. Belirti, derleme gunlugundeki bir
	# satirin YOKLUGU. Fusera'da tam olarak bu oldu.
	var eklenti := PackedStringArray(ProjectSettings.get_setting(
		"editor_plugins/enabled", PackedStringArray()))
	for yol in ["res://addons/admob/plugin.cfg",
			"res://addons/GodotGooglePlayBilling/plugin.cfg"]:
		check(eklenti.has(yol), "eklenti kayitli: %s" % yol)

	# 4) AdMob UYGULAMA KIMLIGI.
	#
	# Ayarin `project.godot`ta GORUNMEMESI tek basina hata degil: eklenti
	# ayari Google'in TEST uygulama kimligiyle kayitliyor ve Godot,
	# varsayilanina esit olan hicbir ayari dosyaya yazmiyor. Disa aktarimda
	# ayni varsayilan yeniden geliyor, yani manifest dogru dolduruluyor.
	#
	# ONEMLI OLAN SU: canli reklam birimleri doldurulmussa uygulama kimligi
	# de GERCEK olmali. Aksi halde istekler Google'in test uygulamasina
	# gidiyor -- birimler canli, oyun calisiyor, panoda tek istek yok.
	var test_app_id := "ca-app-pub-3940256099942544~3347511713"
	var pg := FileAccess.get_file_as_string("res://project.godot")
	var gercek_kimlik := pg.contains("general/android/app_id=") \
		and not pg.contains(test_app_id)
	if AdMobAdProvider.canli_birimler_hazir():
		check(gercek_kimlik,
			"canli birim varken AdMob uygulama kimligi de gercek olmali")
	else:
		print("  NOT: AdMob uygulama kimligi TEST kimligi -- canli birimlerle"
			+ " birlikte guncellenecek")

	# 5) IKONLAR. Yollar `export_presets.cfg`ten OKUNUYOR, teste sabit
	# yazilmiyor: asil risk bir on ayarin VAR OLMAYAN dosyayi gostermesi.
	# Bos birakilan alan ise Godot'un varsayilan robot simgesiyle
	# derlenmesine yol aciyor ve bu, magaza listesinde fark edilmiyor.
	var ep := FileAccess.get_file_as_string("res://export_presets.cfg")
	var re_ikon := RegEx.create_from_string(
		r'launcher_icons/[a-z0-9_]+="(res://[^"]+)"')
	var gorulen := {}
	for m in re_ikon.search_all(ep):
		var yol := m.get_string(1)
		if gorulen.has(yol):
			continue
		gorulen[yol] = true
		check(ResourceLoader.exists(yol), "on ayardaki ikon var: %s" % yol)
	check(gorulen.size() >= 3,
		"on ayarda ikon yollari tanimli (%d)" % gorulen.size())
	# 6) REKLAM BASLATMA ZINCIRI -- bu oyunun en pahali sessiz hatasi.
	#
	# Fusera'da riza akisi yoktu; yerine `if consent_mode != "": _init_sdk()`
	# vardi. `Save.consent` ilk kurulumda "" ve hicbir yerde doldurulmuyor,
	# yani MobileAds.initialize() HIC cagrilmiyor: tek reklam istegi
	# cikmiyor, kod dogru gorunuyor, gelir sifir.
	var kod := _kodu_oku("res://scripts/ads/admob_ad_provider.gd")
	check(kod != "", "reklam saglayicisi okunabiliyor")
	check(not kod.contains('consent_mode != ""'),
		"SDK baslatma bos bir riza dizesine BAGLI DEGIL")
	check(kod.contains("_request_consent()"), "UMP riza akisi cagriliyor")
	# Iki gozcu: biri riza akisi hic donmezse, digeri SDK baslatma geri
	# cagrisi hic donmezse devreye giriyor. Foldera'da ikincisi eksikti ve
	# panoda iki gun boyunca "istek: 0" goruldu.
	check(kod.contains("func _gozcu_baslat"), "riza gozcusu var")
	check(kod.contains("func _yukleme_gozcusu"), "yukleme gozcusu var")
	check(kod.count("preload_all()") >= 2,
		"preload_all hem SDK geri cagrisindan hem gozcuden cagriliyor")

	# 7) CANLI BIRIM KAPISI. Bos birim kimligiyle AdMob istegi sessizce
	# basarisiz oluyor; "liveads" etiketli bir derlemede bu, gelirin
	# tamaminin kaybi demek ve baska hicbir belirtisi yok.
	check(kod.contains("canli_birimler_hazir()"),
		"canli birim kapisi yerinde")

	# 8) ANDROID DERLEME SABLONU. `android/` varsa icinde `.gdignore`
	# BULUNMALI: yoksa duzenleyici o dizini normal proje icerigi saniyor,
	# ilk derleme geciyor, ikincisi kendi ciktisini yeniden icine alip kat
	# kat derinlesen yollarda cokuyor. Hata mesaji eksik bir dosyadan soz
	# ettigi icin asil nedeni gostermiyor.
	var kok := ProjectSettings.globalize_path("res://")
	if DirAccess.dir_exists_absolute(kok + "android"):
		check(FileAccess.file_exists(kok + "android/.gdignore"),
			"android/.gdignore var")
	else:
		print("  NOT: android/ yok -- derleme sablonu henuz kurulmamis")


##
## App Store tarafinin SESSIZ hatalari.
##
## Hepsinin ortak ozelligi su: derleme geciyor, oyun calisiyor, magaza
## sayfasi dolu goruunuyor ve yanlis olan sey yalnizca gelir raporunda
## ya da Apple'in ret mektubunda ortaya cikiyor -- yani haftalar sonra.
##
func t_ios_kurulum() -> void:
	print("- iOS kurulum denetimi")

	var ep := FileAccess.get_file_as_string("res://export_presets.cfg")
	var ios := _on_ayar(ep, "iOS")
	check(ios != "", "iOS on ayari bulundu")
	if ios == "":
		return

	# 1) CANLI REKLAM ETIKETI. Etiket yoksa `_live` false kaliyor ve
	# magazadaki derleme Google'in TEST birimlerini yukluyor: reklam
	# gorunur, oyun calisir, kazanc sifirdir. Mirera 1.0.1 boyle cikti.
	check(ios.contains('custom_features="liveads"'),
		"iOS on ayarinda liveads etiketi var")

	# 2) MAGAZA GORSELLERI VE ARACLAR PAKETE GIRMEMELI.
	# `export_filter=all_resources` her seyi aliyor; Arcera'da magaza
	# goruntuleri boylece 13 MB olu agirlik olarak .pck icine girdi.
	for d in ["store/*", "tools/*", "tests/*", "brand/*"]:
		check(ios.contains(d), "iOS disa aktariminda %s haric" % d)

	# 3) iOS AdMob UYGULAMA KIMLIGI. Android'inkinden AYRI bir ayar; bos
	# birakilirsa eklenti Info.plist'e Google'in TEST kimligini yaziyor.
	var pg := FileAccess.get_file_as_string("res://project.godot")
	check(pg.contains("general/ios/app_id="),
		"project.godot'ta iOS AdMob uygulama kimligi var")
	check(not pg.contains("ca-app-pub-3940256099942544~"),
		"project.godot'ta Google'in TEST uygulama kimligi yok")

	# 4) iOS BIRIMLERI ANDROID'INKINDEN FARKLI OLMALI. AdMob'da uygulama
	# PLATFORM BASINA aciliyor; Android birimini iOS'te kullanmak
	# istekleri yanlis uygulamaya yaziyor.
	check(AdMobAdProvider.LIVE_INTERSTITIAL_IOS != "", "iOS gecis birimi dolu")
	check(AdMobAdProvider.LIVE_REWARDED_IOS != "", "iOS odullu birimi dolu")
	check(AdMobAdProvider.LIVE_INTERSTITIAL_IOS != AdMobAdProvider.LIVE_INTERSTITIAL,
		"iOS gecis birimi Android'inkinden farkli")
	check(AdMobAdProvider.LIVE_REWARDED_IOS != AdMobAdProvider.LIVE_REWARDED,
		"iOS odullu birimi Android'inkinden farkli")

	# 5) KISISELLESTIRME KAPALI. App Store gizlilik etiketinde "izleme
	# yok" yaziyor ve bunun kodda karsiligi olmali: eklenti ATT istemini
	# sunmadigi icin npa=1 gonderiyoruz. Etiketle kodun ayrilmasi
	# Guideline 5.1.2'den ret sebebi.
	var kod := _kodu_oku("res://scripts/ads/admob_ad_provider.gd")
	check(kod.contains('r.extras["npa"] = "1"'), "iOS isteklerinde npa=1")
	check(not kod.contains("AdRequest.new(), cb"),
		"yukleyiciler ciplak AdRequest degil _istek() kullaniyor")

	# 6) APP STORE IKONU. Yol on ayardan OKUNUYOR, teste sabit
	# yazilmiyor: asil risk alanin var olmayan bir dosyayi gostermesi.
	# ALFA KANALI OLMAMALI -- Apple alfali ikonu "Invalid large app
	# icon" ile reddediyor ve bu, derlemenin SONUNDA ortaya cikiyor.
	var re := RegEx.create_from_string(r'icons/app_store_1024x1024="(res://[^"]+)"')
	var m := re.search(ios)
	check(m != null, "on ayarda App Store ikonu tanimli")
	if m != null:
		var yol := m.get_string(1)
		check(FileAccess.file_exists(yol), "App Store ikonu var: %s" % yol)
		if FileAccess.file_exists(yol):
			var ikon := Image.load_from_file(yol)
			check(ikon != null and ikon.get_width() == 1024 and ikon.get_height() == 1024,
				"App Store ikonu 1024x1024")
			check(ikon != null and ikon.detect_alpha() == Image.ALPHA_NONE,
				"App Store ikonunda alfa kanali yok")

	# 7) MAGAZA METINLERI. appstore.json ile copy.json AYNI dilleri
	# tasimali: birinde olup otekinde olmayan bir dil, o dilde yarim
	# kalmis bir urun sayfasi demek.
	var ek: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://store/appstore.json"))
	var cp: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://store/copy.json"))
	check(ek != null and not ek.is_empty(), "store/appstore.json okunabiliyor")
	if ek == null or ek.is_empty() or cp == null:
		return
	var ad: Array = (ek.get("diller", {}) as Dictionary).keys()
	var cd: Array = cp.keys()
	ad.sort()
	cd.sort()
	check(ad == cd, "appstore.json ve copy.json ayni dilleri tasiyor")

	for dil in ad:
		var d: Dictionary = ek.diller[dil]
		for alan in ["apple", "altbaslik", "anahtar", "tanitim"]:
			check(d.has(alan) and str(d[alan]) != "",
				"%s dilinde %s dolu" % [dil, alan])

	# 8) BAGLANTILAR. Destek adresi App Store'da ZORUNLU ve calismayan
	# bir adres Kural 1.5'ten dogrudan ret sebebi -- Arcera'da tam olarak
	# bu oldu: adres on uc dilde bildirildi, sayfa hic yayimlanmamisti.
	var bag: Dictionary = ek.get("baglantilar", {})
	for alan in ["gizlilik", "destek", "pazarlama"]:
		check(bag.has(alan) and str(bag[alan]).begins_with("https://"),
			"baglantilar.%s https adresi" % alan)


##
## `export_presets.cfg` icinden bir on ayarin metnini kesip verir.
##
## Bir on ayar DOSYADA IKI BOLUM: `[preset.N]` ve `[preset.N.options]`.
## Yalnizca ilkini almak `custom_features`i verir ama ikon yolunu
## vermez; ikisi birlikte doneuyor.
func _on_ayar(ham: String, ad: String) -> String:
	var re := RegEx.create_from_string(r"\[preset\.(\d+)\]")
	for m in re.search_all(ham):
		var no := m.get_string(1)
		var bas := m.get_start()
		var sonraki := ham.find("[preset.%d]" % (int(no) + 1), bas)
		var blok := ham.substr(bas) if sonraki < 0 else ham.substr(bas, sonraki - bas)
		if blok.contains('name="%s"' % ad):
			return blok
	return ""


## Kaynak dosyayi YORUM SATIRLARI ATILMIS halde okur.
##
## Sart: bu dosyalarin aciklamalari eski hatalari ORNEK OLARAK iceriyor,
## yani ham metinde arama yapmak kendi aciklamamizi hata sanip yanlis
## alarm veriyor. Denetimin ilk halinde tam olarak bu oldu.
func _kodu_oku(yol: String) -> String:
	if not FileAccess.file_exists(yol):
		return ""
	var out := ""
	for satir in FileAccess.get_file_as_string(yol).split("\n"):
		if satir.strip_edges().begins_with("#"):
			continue
		out += satir + "\n"
	return out


##
## SATILAN HER URUNUN BIR KARSILIGI OLMALI.
##
## Mirera, Fusera'nin magaza katmanini oldugu gibi devraldi ve icinde
## `hints_10` vardi. Ama burada ipucu cuzdani YOK -- ipucu odullu
## reklamdan geliyor ve `_grant` o urunu hicbir seye cevirmiyordu. Urun
## Play Console'da acilsaydi oyuncu para verip hicbir sey almayacakti.
##
## Hicbir belirti vermiyor: kod derleniyor, oyun calisiyor, satin alma
## akisi bile "basarili" donuyor. O yuzden kural teste baglandi: PRODUCTS
## icindeki her kimlik, `_grant` govdesinde gecmek ZORUNDA.
func t_urun_karsiligi() -> void:
	print("- urun karsiligi")
	var S = load("res://scripts/store/store_service.gd")
	var kod := _kodu_oku("res://scripts/store/store_service.gd")
	var govde := kod.substr(kod.find("func _grant("))
	check(govde != "", "_grant bulunabiliyor")
	for id in S.PRODUCTS.keys():
		check(govde.contains('"%s"' % id),
			"%s urununun _grant icinde karsiligi var" % id)
