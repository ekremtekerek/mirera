extends Node
##
## Ilerleme (autoload: Save). Cihazda kaliyor, hicbir yere gonderilmiyor.

const PATH := "user://mirera.cfg"

var unlocked := 1
var stars := {}          ## seviye -> 1..3
var ads_removed := false
var levels_since_ad := 0
var consent := ""
var theme := "kor"
## Siralamaya temel olacak olculer. Toplam yildiz asil puan; en uzun
## zincir ise karsilastirilabilir ve eglenceli bir yan olcu.
var best_chain := 0
## Ilk seviyedeki rehber gosterildi mi. Bir kez gosterilip bir daha
## cikmiyor: her acilista tekrarlanan ogretim, oyunu bilen oyuncu icin
## en hizli birakma sebeplerinden biri.
var taught := false


func _ready() -> void:
	load_data()
	# Komut satirindan tema zorlama: `-- gece` gibi. Arayuz kurulmadan ONCE
	# calismasi sart -- etiketler ve dugmeler rengi kuruldugu anda aliyor,
	# sonra uygulanan tema onlara islemiyor.
	for a in OS.get_cmdline_user_args():
		for t in Themes.LIST:
			if a == str(t.id):
				theme = str(t.id)
	# Tema kaydedilmis ama artik kilitliyse (ilerleme silinmisse) varsayilana
	# donuyoruz; kilitli tema gosterip odulu anlamsizlastirmamak icin.
	var acik := Themes.by_stars(total_stars())
	var gecerli := false
	for t in acik:
		if str(t.id) == theme: gecerli = true
	if not gecerli and not _zorlandi(): theme = "kor"
	Palette.apply(Themes.find(theme))


func star_of(level: int) -> int:
	return int(stars.get(level, 0))


func total_stars() -> int:
	var n := 0
	for v in stars.values():
		n += int(v)
	return n


## Yildiz ASLA dusmuyor: bir kez uc yildiz alan seviye tekrar oynanip
## kotu sonuc verse bile eski sonucu koruyor. Tersi, oyuncuyu kendi
## rekorunu bozma korkusuyla tekrar oynamaktan cayiriyor.
func record(level: int, star: int) -> void:
	if star > star_of(level):
		stars[level] = star
	unlocked = maxi(unlocked, level + 1)
	save_data()


func load_data() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	unlocked = int(cf.get_value("ilerleme", "unlocked", 1))
	ads_removed = bool(cf.get_value("econ", "ads_removed", false))
	levels_since_ad = int(cf.get_value("econ", "levels_since_ad", 0))
	consent = str(cf.get_value("econ", "consent", ""))
	theme = str(cf.get_value("ilerleme", "theme", "kor"))
	best_chain = int(cf.get_value("ilerleme", "best_chain", 0))
	taught = bool(cf.get_value("ilerleme", "taught", false))
	stars = cf.get_value("ilerleme", "stars", {})


func save_data() -> void:
	var cf := ConfigFile.new()
	cf.set_value("ilerleme", "unlocked", unlocked)
	cf.set_value("econ", "ads_removed", ads_removed)
	cf.set_value("econ", "levels_since_ad", levels_since_ad)
	cf.set_value("econ", "consent", consent)
	cf.set_value("ilerleme", "theme", theme)
	cf.set_value("ilerleme", "best_chain", best_chain)
	cf.set_value("ilerleme", "taught", taught)
	cf.set_value("ilerleme", "stars", stars)
	cf.save(PATH)


## Tema komut satirindan mi geldi. Cekim araclari kilitli temayi da
## gorebilsin diye; oyunda bu yol hic calismiyor.
func _zorlandi() -> bool:
	for a in OS.get_cmdline_user_args():
		for t in Themes.LIST:
			if a == str(t.id):
				return true
	return false


## Siralama puani. Toplam yildiz secildi cunku KARSILASTIRILABILIR: herkes
## ayni seviyeleri oynuyor ve ayni tavana sahip. "Kac seviye actin" olcusu
## yalnizca kim daha cok zaman harcadigini olcerdi.
func score() -> int:
	return total_stars()
