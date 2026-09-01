class_name Palette
extends RefCounted
##
## Aktif temanin renkleri.
##
## Degerler `static var` -- yani `Palette.BG` yazan butun cagri noktalari
## degismeden calisiyor ama tema degistiginde hepsi birden guncelleniyor.
## Sabit (const) birakip her yere tema parametresi tasimak yuzlerce satir
## degisiklik demekti.
##
## SICAK ISIK yonu korunuyor ama tema secilebilir. Her temada
## sonuk ve yanan hedef IKI EKSENDE birden ayrisiyor -- parlaklik ve doygunluk.
## Tek eksende ayirmak (orn. yalnizca renk) renk korlugu olan oyuncuda
## kayboluyor; iki eksen guvenli. Bu kural her yeni temada korunmali.

static var BG := Color("#faf3e8")
static var BG_DEEP := Color("#f0e5d4")
static var GRID := Color("#e2d5c0")

static var DIM := Color("#c9bba6")
static var DIM_DEEP := Color("#9a8b74")
static var RING := Color("#b3a288")
static var ARROW := Color("#a08f76")

static var BEAM := Color("#ffb43d")
static var CORE := Color("#fff6e0")
static var GLOW := Color("#ff9c2b")

static var BEAM_HOT := Color("#ff7a45")
static var BEAM_TAIL := Color("#ffd9a8")
static var SPARK := Color("#e8541f")

static var MIRROR := Color("#7fb5c4")
static var MIRROR_EDGE := Color("#5c93a3")
static var WALL := Color("#8d8375")

static var INK := Color("#3a322a")
static var INK_SOFT := Color("#8b7f6d")
static var ACCENT := Color("#e4664f")
static var ACCENT_DEEP := Color("#b8462f")
static var BTN_FACE := Color("#ece0cc")
static var BTN_EDGE := Color("#cbb99c")
static var CARD_EDGE := Color("#d3c2a6")
static var STAR := Color("#f5c243")
static var STAR_EMPTY := Color("#ddd0b8")


## Temayi uygular. Ikincil renkler ana renklerden TURETILIYOR: her temada
## on dokuz renk elle yazmak hem hataya acik hem bakimsiz olurdu.
static func apply(t: Dictionary) -> void:
	BG = Color(str(t.bg))
	BG_DEEP = Color(str(t.deep))
	GRID = Color(str(t.grid))
	DIM = Color(str(t.idle))
	DIM_DEEP = Color(str(t.dark))
	RING = Color(str(t.ring))
	ARROW = Color(str(t.arrow))
	BEAM = Color(str(t.lit))
	CORE = Color(str(t.core))
	GLOW = Color(str(t.glow))
	BEAM_HOT = Color(str(t.pulse))
	BEAM_TAIL = Color(str(t.tail))
	SPARK = Color(str(t.spark))
	INK = Color(str(t.ink))
	INK_SOFT = Color(str(t.soft))
	ACCENT = Color(str(t.accent))
	ACCENT_DEEP = Color(str(t.accent_deep))

	# Turetilenler: dugme ve kart yuzeyleri zeminden bir tik ayrisiyor,
	# alt kenarlar onlardan bir tik koyu.
	BTN_FACE = BG_DEEP.lerp(BG, 0.35)
	BTN_EDGE = BTN_FACE.darkened(0.18)
	CARD_EDGE = BG_DEEP.darkened(0.14)
	# Ayna SOGUK kalmali: sicak paletten ayrisan tek tas o.
	MIRROR = Color("#7fb5c4") if BG.get_luminance() > 0.5 else Color("#5ce1e6")
	MIRROR_EDGE = MIRROR.darkened(0.25)
	WALL = INK.lerp(BG, 0.62)
	STAR = Color("#f5c243")
	STAR_EMPTY = INK_SOFT.lerp(BG, 0.5)


static func beam_at(t: float) -> Color:
	return DIM.lerp(BEAM, clampf(t, 0.0, 1.0))


static func glow_alpha(t: float) -> float:
	# Hizli yukselip yavas sonen egri; ani "cak" hissi veriyor.
	if t < 0.15:
		return t / 0.15
	return maxf(0.0, 1.0 - (t - 0.15) / 0.85)
