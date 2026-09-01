class_name LevelGen
extends RefCounted
##
## Seviye uretici: once COZUMU kur, sonra karistir.
##
## Ters yon -- rastgele tahta at, cozulur mu diye bak -- hem yavas hem de
## cozulemez seviyeyi yalnizca ISTATISTIKSEL olarak eliyor. Burada isigin
## yolu tahtaya once dogru haliyle yaziliyor: kaynaktan basliyoruz, birkac
## kez donuyoruz, sonuncu donusun ardindan hedefi koyuyoruz. Yani cozum
## INSAATIN KENDISI. Ardindan aynalarin bir kismi ters cevriliyor.
##
## Boylece "cozulemez seviye" bir olasilik degil, imkansizlik: karistirma
## yalnizca yonelim degistiriyor, yolun geometrisini degil.
##
## Geriye tek soru kaliyor -- KAC dokunusla cozulur -- ve onu Solver
## sayiyor. Bandin disinda kalan aday cope gidiyor.

const SEED_TAG := "mirera-v1"

## Rol haritasi: uretici, hangi hucreye ne konabilecegini bununla takip
## ediyor. En kritik olan BOS_KALMALI: isigin duz gectigi hucreler. Oraya
## sonradan bir tuzak aynasi konursa cozum sessizce bozulur -- yani seviye
## "uretici dogru diyor ama oynanmiyor" durumuna duser.
const SERBEST := 0
const BOS_KALMALI := 1
const DOLU := 2


##
## Seviyeye gore tahta ve zorluk ayarlari.
##
## Ilk uc seviye TEK AYNA, tuzaksiz, duvarsiz: oyuncu bir kez dokunuyor,
## isin donuyor, hedef yaniyor. Ogretici karti yok cunku gerek yok --
## bu her dilde ayni sekilde anlasiliyor.
##
## Yeni unsurlar TEK TEK giriyor: tuzak ayna 9, duvar 16, ikinci hedef
## ve bolucu daha sonra. Hepsini birden vermek ogrenmeyi degil ezberi
## zorunlu kilardi.
static func difficulty(level: int) -> Dictionary:
	var w := 4
	var h := 4
	var turns := 1
	var decoys := 0
	var walls := 0
	var par_min := 1
	var par_max := 1

	if level > 3:
		w = 4; h = 5
		turns = 2; par_max = 2
	if level > 8:
		w = 5; h = 5
		turns = 2; decoys = 1; par_min = 2; par_max = 3
	if level > 15:
		w = 5; h = 6
		turns = 3; decoys = 1; walls = 1; par_min = 2; par_max = 4
	if level > 25:
		w = 6; h = 6
		turns = 3; decoys = 2; walls = 2; par_min = 3; par_max = 5
	if level > 40:
		w = 6; h = 7
		turns = 4; decoys = 2; walls = 3; par_min = 3; par_max = 5
	if level > 60:
		w = 7; h = 7
		turns = 4; decoys = 3; walls = 3; par_min = 3; par_max = 6

	return {
		"w": w, "h": h, "turns": turns, "decoys": decoys, "walls": walls,
		"par_min": par_min, "par_max": par_max,
	}


##
## Bir seviye uretir: {"grid": Grid, "par": int, "cfg": Dictionary}.
##
## Tohum seviye numarasindan geliyor, yani ayni seviye her cihazda ve her
## acilista AYNI. Bu bir tercih degil zorunluluk: yildizlar ve ipuclari
## seviyeye gore kaydediliyor, tahta degisirse kayit anlamsiz olur.
static func generate(level: int, attempts: int = 60) -> Dictionary:
	var cfg := difficulty(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [SEED_TAG, level])

	# Bandi tutturamazsak bandi GENISLETIYORUZ, seviyeyi bozmuyoruz:
	# oynanabilir ama biraz kolay bir bolum, hic bolum olmamasindan iyi.
	var yedek := {}
	for a in attempts:
		var g := _build(cfg, rng)
		if g == null:
			continue
		var p := Solver.par(g, cfg.par_max)
		if p < 1:
			continue
		if p >= cfg.par_min and p <= cfg.par_max:
			return {"grid": g, "par": p, "cfg": cfg}
		if yedek.is_empty():
			yedek = {"grid": g, "par": p, "cfg": cfg}
	if not yedek.is_empty():
		return yedek
	# Buraya dusmek uretici hatasi demek; testte `t_uretim()` bunu yakaliyor.
	push_error("[gen] seviye %d uretilemedi" % level)
	return {"grid": _acil_durum(), "par": 1, "cfg": cfg}


##
## Tek bir aday tahta. Basarisiz olursa null -- cagiran taraf yeniden
## deniyor. Basarisizlik normal: dar tahtada rastgele secilen donus yonu
## siklikla kenara sikisiyor.
static func _build(cfg: Dictionary, rng: RandomNumberGenerator) -> Grid:
	var w: int = cfg.w
	var h: int = cfg.h
	var g := Grid.new(w, h)
	var role := PackedInt32Array()
	role.resize(w * h)

	# Kaynak bir kenarda, ice bakiyor. Kose KASTEN eleniyor: kosede duran
	# kaynak, isini tahtanin en dis seridine yapistiriyor ve seviye "tek
	# satirlik" gorunuyor.
	var kenar := rng.randi_range(0, 3)
	var uzun := h if (kenar == 0 or kenar == 2) else w
	var p := rng.randi_range(1, maxi(1, uzun - 2))
	var sx := 0
	var sy := 0
	var sd := Grid.YON_SAG
	match kenar:
		0: sx = 0;     sy = p; sd = Grid.YON_SAG
		1: sx = p;     sy = 0; sd = Grid.YON_ASAGI
		2: sx = w - 1; sy = p; sd = Grid.YON_SOL
		3: sx = p;     sy = h - 1; sd = Grid.YON_YUKARI

	var cur := sy * w + sx
	g.kind[cur] = Grid.SOURCE
	g.state[cur] = sd
	role[cur] = DOLU

	var d := sd
	for t in cfg.turns:
		# Sola ya da saga donus. Duz devam ya da geri donus yok: ayna
		# zaten 90 derece cevirir, digeri fizik degil.
		var nd := (d + (1 if rng.randi() % 2 == 0 else 3)) % 4
		var secenek := _runs(g, role, cur, d, nd, true)
		if secenek.is_empty():
			# Secilen donus yonu sikismis; DIGER yonu deniyoruz. `d` etrafinda
			# yansitma: (d+1) <-> (d+3).
			nd = (2 * d + 4 - nd) % 4
			secenek = _runs(g, role, cur, d, nd, true)
			if secenek.is_empty():
				return null
		var r: int = secenek[rng.randi() % secenek.size()]
		cur = _mark(g, role, cur, d, r)
		g.kind[cur] = Grid.MIRROR
		g.state[cur] = Grid.orient_for(d, nd)
		role[cur] = DOLU
		d = nd

	# Son duz parca ve hedef.
	var son := _runs(g, role, cur, d, d, false)
	if son.is_empty():
		return null
	var rr: int = son[rng.randi() % son.size()]
	cur = _mark(g, role, cur, d, rr)
	g.kind[cur] = Grid.TARGET
	role[cur] = DOLU

	# Tuzak aynalar ve duvarlar YALNIZCA serbest hucrelere. BOS_KALMALI
	# isaretli hucreye konursa cozum bozulur; bu, uretimde yakalanmasi zor
	# bir hata olurdu cunku seviye hala "uretildi" gorunur.
	for i in int(cfg.decoys):
		var c := _serbest_hucre(role, rng)
		if c < 0:
			break
		g.kind[c] = Grid.MIRROR
		g.state[c] = rng.randi() % 2
		role[c] = DOLU
	for i in int(cfg.walls):
		var c2 := _serbest_hucre(role, rng)
		if c2 < 0:
			break
		g.kind[c2] = Grid.WALL
		role[c2] = DOLU

	_karistir(g, rng)
	return g


##
## Aynalarin bir kismini ters cevirir. En az biri KESIN cevriliyor, yoksa
## seviye acildigi anda cozulmus olur ve oyuncu ne oldugunu anlamaz.
static func _karistir(g: Grid, rng: RandomNumberGenerator) -> void:
	var ms := g.mirrors()
	if ms.is_empty():
		return
	var oldu := false
	for i in ms:
		if rng.randi() % 2 == 0:
			g.toggle(i)
			oldu = true
	if not oldu:
		g.toggle(ms[rng.randi() % ms.size()])


##
## `from` hucresinden `d` yonunde gidilebilecek mesafeler.
##
## Kural: DOLU hucre gecilemez; BOS_KALMALI hucrenin UZERINDEN gecilir ama
## uzerine bir sey KONAMAZ (orasi isigin duz gectigi yer). Ayna icin ayrica
## donus yonunde en az bir hucre kalmasi araniyor, yoksa ayna isigi hemen
## tahtanin disina atar.
static func _runs(g: Grid, role: PackedInt32Array, from: int, d: int,
		next_d: int, ayna_icin: bool) -> Array:
	var out: Array = []
	var x := g.cx(from)
	var y := g.cy(from)
	var r := 0
	while true:
		r += 1
		x += Grid.DX[d]
		y += Grid.DY[d]
		if not g.inside(x, y):
			break
		var c := y * g.w + x
		if role[c] == DOLU:
			break
		if role[c] == SERBEST:
			if not ayna_icin:
				out.append(r)
			elif g.inside(x + Grid.DX[next_d], y + Grid.DY[next_d]):
				out.append(r)
	return out


## Yolu isaretler ve varilan hucreyi doner. Ara hucreler BOS_KALMALI oluyor.
static func _mark(g: Grid, role: PackedInt32Array, from: int, d: int, r: int) -> int:
	var x := g.cx(from)
	var y := g.cy(from)
	var c := from
	for i in r:
		x += Grid.DX[d]
		y += Grid.DY[d]
		c = y * g.w + x
		if i < r - 1 and role[c] == SERBEST:
			role[c] = BOS_KALMALI
	return c


static func _serbest_hucre(role: PackedInt32Array, rng: RandomNumberGenerator) -> int:
	var aday := PackedInt32Array()
	for i in role.size():
		if role[i] == SERBEST:
			aday.append(i)
	if aday.is_empty():
		return -1
	return aday[rng.randi() % aday.size()]


## Uretici tamamen basarisiz olursa gosterilecek, elle kurulmus tahta.
## Oyunun bos ekranla acilmasindansa kolay bir bolum gostermesi iyidir.
static func _acil_durum() -> Grid:
	var g := Grid.new(3, 3)
	g.kind[g.idx(0, 1)] = Grid.SOURCE
	g.state[g.idx(0, 1)] = Grid.YON_SAG
	g.kind[g.idx(1, 1)] = Grid.MIRROR
	g.state[g.idx(1, 1)] = 1              # "\" -> sag'dan asagi; dogrusu "/"
	g.kind[g.idx(1, 0)] = Grid.TARGET
	return g
