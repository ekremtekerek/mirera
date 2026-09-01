class_name Grid
extends RefCounted
##
## Tahta ve isik yayilimi. SAF veri + saf fonksiyon: sahne agacina, zamana
## ya da girdiye hic dokunmuyor.
##
## Bu ayrim kasitli. Oyunun butun dogrulugu tek bir soruya iniyor -- "bu
## tahtada isik hedefe variyor mu" -- ve bu soru gorsel katman olmadan
## binlerce kez calistirilabiliyor. Seviye ureticisi de, cozucusu de,
## testler de ayni `_yuru` fonksiyonunu kullaniyor; yani oyunun oynanisi
## ile uretimin kabul olcutu ayni koda dayaniyor, iki ayri gerceklige
## degil. Foldera'da bu ayrim yoktu ve "uretici cozulebilir diyor ama
## oyunda cozulmuyor" sinifindan hatalar cikmisti.

enum { EMPTY, WALL, MIRROR, SPLIT, SOURCE, TARGET }

## Yonler: 0=sag 1=asagi 2=sol 3=yukari.
## Sira KEYFI DEGIL -- yansima formulleri buna dayaniyor (bkz. `reflect`).
## Tur ACIKCA yazili: turlenmemis `Array` sabitinden okunan deger Variant
## oluyor ve `cx(i) + DX[d]` ifadesi tur cikarimini bozuyor.
const DX: Array[int] = [1, 0, -1, 0]
const DY: Array[int] = [0, 1, 0, -1]

const YON_SAG := 0
const YON_ASAGI := 1
const YON_SOL := 2
const YON_YUKARI := 3

var w: int
var h: int
## Hucre turu (yukaridaki enum).
var kind: PackedInt32Array
## Hucreye gore ikinci deger:
##   MIRROR / SPLIT -> yonelim, 0 = "/", 1 = "\"
##   SOURCE         -> isigin cikis yonu
##   digerleri      -> kullanilmiyor
var state: PackedInt32Array


func _init(width: int, height: int,
		k := PackedInt32Array(), s := PackedInt32Array()) -> void:
	w = width
	h = height
	var n := w * h
	kind = k.duplicate() if k.size() == n else PackedInt32Array()
	state = s.duplicate() if s.size() == n else PackedInt32Array()
	# resize sifirla dolduruyor; EMPTY zaten 0, yani bos tahta dogru cikiyor.
	kind.resize(n)
	state.resize(n)


func idx(x: int, y: int) -> int:
	return y * w + x


func cx(i: int) -> int:
	return i % w


func cy(i: int) -> int:
	return i / w


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h


func clone() -> Grid:
	return Grid.new(w, h, kind, state)


##
## Aynadan yansiyan yon.
##
## "/" aynasi sag->yukari, yukari->sag, sol->asagi, asagi->sol yapiyor;
## yon numaralari 0..3 sirasiyla sag/asagi/sol/yukari oldugu icin bu tam
## olarak `3 - d`. "\" aynasi ise sag<->asagi ve sol<->yukari, yani `d ^ 1`.
##
## Yon sirasini degistirirsen bu iki satir sessizce yanlis olur; testte
## `t_yansima()` tam bunu bekliyor.
static func reflect(d: int, orient: int) -> int:
	return (3 - d) if orient == 0 else (d ^ 1)


##
## Bir aynanin, isigi `d` yonunden alip `nd` yonune cevirmesi icin gereken
## yonelim. Uretici, yolu kurarken aynayi buna gore yerlestiriyor.
static func orient_for(d: int, nd: int) -> int:
	return 0 if nd == 3 - d else 1


func toggle(i: int) -> void:
	state[i] = 1 - state[i]


## Dokunulabilir aynalarin hucre numaralari. SPLIT bilerek DISARIDA:
## oyuncunun dokunabilecegi tek sey ayna olsun istiyoruz, yoksa "neye
## basabilirim" sorusu her seviyede yeniden soruluyor.
func mirrors() -> PackedInt32Array:
	var m := PackedInt32Array()
	for i in kind.size():
		if kind[i] == MIRROR:
			m.append(i)
	return m


func target_count() -> int:
	var n := 0
	for i in kind.size():
		if kind[i] == TARGET:
			n += 1
	return n


##
## Cozuldu mu. Cozucunun sicak dongusu bunu binlerce kez cagirdigi icin
## adim listesi URETILMIYOR -- yalnizca hedefler sayiliyor.
func is_solved() -> bool:
	return _yuru(false)["solved"]


##
## Cizim icin tam iz: her adim {"cell", "in", "out"}.
##   in  == -1  -> isigin dogdugu hucre (kaynak)
##   out == -1  -> isigin yutuldugu hucre (duvar, hedef, kaynak govdesi)
func trace() -> Dictionary:
	return _yuru(true)


##
## Isik yayilimi. Durum = (hucre, yon) ciftleri; ayni cifte ikinci kez
## girilmiyor, boylece iki ayna arasinda hapsolan isin sonsuz donguye
## girmek yerine sessizce duruyor.
##
## Kuyruk kullaniliyor cunku SPLIT isini IKIYE boluyor; tek bir "suru
## takip et" dongusu bunu tasiyamaz.
func _yuru(topla: bool) -> Dictionary:
	var steps: Array = []
	var hit := {}
	var seen := {}
	# Kuyruk ogesi: [hucre, yon] = "isik bu hucreden bu yone dogru cikiyor".
	var queue: Array = []

	for i in kind.size():
		if kind[i] == SOURCE:
			if topla:
				steps.append({"cell": i, "in": -1, "out": state[i]})
			queue.append([i, state[i]])

	var qi := 0
	while qi < queue.size():
		var cur: Array = queue[qi]
		qi += 1
		var from: int = cur[0]
		var d: int = cur[1]
		var nx := cx(from) + DX[d]
		var ny := cy(from) + DY[d]
		if not inside(nx, ny):
			continue
		var c := ny * w + nx
		var key := c * 4 + d
		if seen.has(key):
			continue
		seen[key] = true

		match kind[c]:
			WALL, SOURCE:
				if topla:
					steps.append({"cell": c, "in": d, "out": -1})
			TARGET:
				hit[c] = true
				if topla:
					steps.append({"cell": c, "in": d, "out": -1})
			MIRROR:
				var nd := reflect(d, state[c])
				if topla:
					steps.append({"cell": c, "in": d, "out": nd})
				queue.append([c, nd])
			SPLIT:
				# Bolucu: bir kol yansiyor, digeri duz devam ediyor.
				var yansi := reflect(d, state[c])
				if topla:
					steps.append({"cell": c, "in": d, "out": yansi})
					steps.append({"cell": c, "in": d, "out": d})
				queue.append([c, yansi])
				queue.append([c, d])
			_:
				if topla:
					steps.append({"cell": c, "in": d, "out": d})
				queue.append([c, d])

	var hedef := target_count()
	return {
		"steps": steps,
		"hit": hit,
		"solved": hedef > 0 and hit.size() == hedef,
	}
