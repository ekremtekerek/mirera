class_name Solver
extends RefCounted
##
## "Bu tahta kac dokunusla cozulur?" -- tek soru, iki kullanici:
##   * Uretici, bandin disinda kalan seviyeleri COPE atiyor.
##   * Oyun, yildiz esigini ve ipucunu buradan aliyor.
##
## Aynalar iki durumlu oldugu icin cozum = hangi aynalarin cevrilecegi,
## yani baslangic durumundan cozume olan HAMMING UZAKLIGI. Bu yuzden
## 2^n durumun tamamini taramak gereksiz: k=1,2,3... diye ARTAN boyutta
## alt kumeler deneniyor ve ilk bulunan k zaten en kucugu oluyor.
##
## 14 ayna ve k<=6 icin bu ~10 bin simulasyon; tam tarama 16384 durumun
## her birini gezerdi ve tipik seviyede cevap 2-3'te bulunuyor.

## Bir seviyede beklenen en fazla dokunus. Ustu aranmiyor: hyper-casual
## bir bolumde 8 dokunusluk cozum zaten yanlis tasarlanmis demektir.
const MAX_TAPS := 8

## Sert tavan. Uretici kotu bir aday urettiginde arama patlayabilir;
## bu durumda seviyeyi REDDETMEK, oyuncuyu bekletmekten iyidir.
const SIM_BUDGET := 60000


##
## En az dokunus sayisi. Zaten cozulmusse 0, `cap` icinde bulunamazsa -1.
static func par(g: Grid, cap: int = MAX_TAPS) -> int:
	if g.is_solved():
		return 0
	var m := g.mirrors()
	if m.is_empty():
		return -1
	var butce := [SIM_BUDGET]
	var calisma := g.clone()
	for k in range(1, mini(cap, m.size()) + 1):
		var pick := PackedInt32Array()
		pick.resize(k)
		if _ara(calisma, m, k, 0, 0, pick, butce):
			return k
		if butce[0] <= 0:
			return -1
	return -1


##
## Cozume goturen ayna kumesi (bos dizi = zaten cozulmus, bos DEGIL ama
## bulunamadiysa da bos doner -- ayirt etmek gerekirse `par` ile bak).
##
## Ipucu bunu kullaniyor: kumenin ILK aynasini isaretliyoruz. Tam cozumu
## gostermek odulu anlamsizlastirirdi; tek bir dogru hamle oyuncuyu
## tikandigi yerden cikariyor, gerisini yine kendisi buluyor.
static func solution(g: Grid, cap: int = MAX_TAPS) -> PackedInt32Array:
	if g.is_solved():
		return PackedInt32Array()
	var m := g.mirrors()
	var butce := [SIM_BUDGET]
	var calisma := g.clone()
	for k in range(1, mini(cap, m.size()) + 1):
		var pick := PackedInt32Array()
		pick.resize(k)
		if _ara(calisma, m, k, 0, 0, pick, butce):
			return pick
		if butce[0] <= 0:
			break
	return PackedInt32Array()


##
## k boyutlu alt kumeleri sirayla deniyor. Tahtayi yerinde degistirip geri
## aliyor -- her aday icin klon uretmek bu dongude en pahali islem olurdu.
static func _ara(g: Grid, m: PackedInt32Array, k: int, depth: int, start: int,
		pick: PackedInt32Array, butce: Array) -> bool:
	if depth == k:
		butce[0] -= 1
		if butce[0] <= 0:
			return false
		for i in pick:
			g.toggle(i)
		var ok := g.is_solved()
		for i in pick:
			g.toggle(i)
		return ok
	# Son eleman icin yeterli aday kalmayan baslangiclari hic denemiyoruz.
	for i in range(start, m.size() - (k - depth) + 1):
		pick[depth] = m[i]
		if _ara(g, m, k, depth + 1, i + 1, pick, butce):
			return true
	return false
