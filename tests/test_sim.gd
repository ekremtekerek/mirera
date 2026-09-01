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
	t_export_safety()
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

	check(AdMobAdProvider.canli_birimler_hazir()
		== (AdMobAdProvider.LIVE_INTERSTITIAL != ""
			and AdMobAdProvider.LIVE_REWARDED != ""),
		"canli birim kapisi iki kimligi de ariyor")
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
