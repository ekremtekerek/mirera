extends Node
##
## Ses (autoload: Sfx).
##
## Tasarimin asil fikri: her dalgada PERDE YUKSELIYOR. Uzun bir zincir
## yukselen bir arpej caliyor ve kulak zincirin ilerledigini duyuyor --
## goz ekrana bakmasa bile. Sabit perdeli patlama sesi ayni zinciri
## monoton bir takirtiya cevirmisti.
##
## Perde PENTATONIK bir dizide yurupor: hangi sirayla calarsa calsin
## kulaga uyumlu geliyor. Kromatik olsaydi uzun zincirler tiz ve tirmalayici
## olurdu.

const POP := preload("res://audio/pop.wav")
const CHIME := preload("res://audio/chime.wav")
const TAP := preload("res://audio/tap.wav")

## Pentatonik yariton adimlari (majör pentatonik): 0 2 4 7 9
const DIZI := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]

var sfx_on := true

var _havuz: Array[AudioStreamPlayer] = []
var _at := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Havuz: ayni anda birden fazla patlama calabilmeli. Tek oynatici
	# kullanilsa hizli zincirde sesler birbirini keserdi.
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_havuz.append(p)


func _next() -> AudioStreamPlayer:
	var p := _havuz[_at]
	_at = (_at + 1) % _havuz.size()
	return p


## Zincir patlamasi. `wave` arttikca perde diziyi tirmaniyor.
func burst(wave: int) -> void:
	if not sfx_on:
		return
	var adim: int = DIZI[mini(wave, DIZI.size() - 1)]
	var p := _next()
	p.stream = POP
	p.pitch_scale = pow(2.0, adim / 12.0)
	# Yuksek perdeler kulakta daha yuksek duyuluyor; dengelemek icin
	# hafifce kisiyoruz.
	p.volume_db = -1.5 * (adim / 12.0)
	p.play()


func win() -> void:
	if not sfx_on:
		return
	var p := _next()
	p.stream = CHIME
	p.pitch_scale = 1.0
	p.volume_db = -3.0
	p.play()


func tap() -> void:
	if not sfx_on:
		return
	var p := _next()
	p.stream = TAP
	p.pitch_scale = randf_range(0.96, 1.05)
	p.volume_db = -8.0
	p.play()
