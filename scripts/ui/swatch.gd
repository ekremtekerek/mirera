extends Control
##
## Tema renk ornegi: uc daire yan yana. Kilitli temada solgun ciziliyor --
## rengi tamamen gizlemek yerine "var ama senin degil" demek daha iyi bir
## hedef duygusu veriyor.

@export var renkler: Array = []
@export var solgun := false


func _draw() -> void:
	if renkler.is_empty():
		return
	# Yaricap HEM yukseklige HEM genislige sigmali. Yalnizca size.y'ye
	# bakmak, satir yuksekligi bekledigimden buyuk olunca daireleri tasirip
	# ismin ustune bindiriyordu.
	var r := minf(size.y * 0.42, size.x / 5.8)
	for i in renkler.size():
		var c: Color = renkler[i]
		if solgun:
			c = c.lerp(Palette.BG, 0.55)
		var p := Vector2(r + i * (r * 1.75), size.y * 0.5)
		draw_circle(p, r, c)
		draw_arc(p, r, 0.0, TAU, 28, Palette.INK.lerp(Palette.BG, 0.7), 1.5, true)
