extends Node
##
## Dayaniklilik kosusu: bolumleri GERCEK DOKUNUS YOLUNDAN oynayip biten
## akisi bastan sona surer.
##
##   godot --path . -- soak
##   godot --path . -- soak 120        (bolum sayisi)
##
## `test_sim.gd` mantigi kaniti; bu ise GORSEL KATMANI sinar. Ikisi ayri
## sorulari cevapliyor:
##
##   test  -> "bu tahta cozulebilir mi"
##   soak  -> "oyuncu onu cozebilir mi, ve cozunce ne oluyor"
##
## Aradaki fark onemli: cozucu dogru cevabi verirken dokunus eslemesi
## kaymis, kazanma karti acilmamis ya da bir sonraki bolum yuklenmemis
## olabilir. Bunlarin hicbiri mantik testine dusmez.

var main: Node
var _adet := 60
var _hata := 0
var _cozulen := 0
var _dokunus := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_adet = int(a)
	main = get_parent()
	_run()


func _run() -> void:
	await _sec(0.3)
	print("\n=== MIRERA dayaniklilik kosusu: %d bolum ===\n" % _adet)
	for lv in range(1, _adet + 1):
		main.level = lv
		main._start_level()
		await _sec(0.05)

		var b: BoardView = main.board
		if b.grid == null:
			print("  HATA: seviye %d tahtasi yuklenmedi" % lv)
			_hata += 1
			continue

		# Cozumu GERCEK dokunus yoluyla uyguluyoruz. `grid.toggle` cagirmak
		# girdi katmanini atlar ve tam da olcmek istedigimiz seyi -- ekran
		# konumundan hucreye esleme -- sinamadan birakirdi.
		var sol := Solver.solution(b.grid)
		if sol.is_empty():
			print("  HATA: seviye %d icin cozum bulunamadi" % lv)
			_hata += 1
			continue
		for idx in sol:
			_dokun(b, idx)
		_dokunus += sol.size()

		if not b.grid.is_solved():
			print("  HATA: seviye %d dokunus sonrasi cozulmedi" % lv)
			_hata += 1
			continue
		if b.taps != sol.size():
			print("  HATA: seviye %d dokunus sayaci %d, beklenen %d"
				% [lv, b.taps, sol.size()])
			_hata += 1
		# Par kadar dokunusla cozuldu: uc yildiz olmali.
		if Stars.rate(b.taps, b.par) != 3:
			print("  HATA: seviye %d par ile cozuldu ama uc yildiz degil" % lv)
			_hata += 1
		_cozulen += 1

		# Kazanma akisi: kart aciliyor ve HUD kapaniyor. Reklam araya
		# girebildigi icin biraz bekliyoruz.
		await _sec(1.3)
		if not main._win.visible:
			print("  HATA: seviye %d kazanma karti acilmadi" % lv)
			_hata += 1
		main._win.visible = false

		# Sifirlama yolu da her bolumde bir kez geciliyor: eski durumu geri
		# yuklemek ve sayaci sifirlamak, gozle fark edilmeyecek bir yerde
		# bozulabilecek iki islem.
		b.reset_level()
		if b.taps != 0:
			print("  HATA: seviye %d sifirlamadan sonra sayac sifir degil" % lv)
			_hata += 1

	print("\n%d bolum cozuldu, %d dokunus, %d hata" % [_cozulen, _dokunus, _hata])
	get_tree().quit(1 if _hata > 0 else 0)


func _dokun(b: BoardView, idx: int) -> void:
	b._tap(b._origin + Vector2(b.grid.cx(idx) + 0.5, b.grid.cy(idx) + 0.5) * b._cell)


func _sec(s: float) -> void:
	await get_tree().create_timer(s).timeout
