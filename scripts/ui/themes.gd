class_name Themes
extends RefCounted
##
## Tema koleksiyonu.
##
## Her sey kodla cizildigi icin bir tema aslinda sadece bir RENK KUMESI --
## yeni gorunum eklemek varlik dosyasi degil, birkac satir demek. Bu, "tek
## gorunum sikici" sorununu ucuza cozuyor.
##
## Acilis esikleri TOPLAM YILDIZA bagli: oyuncu ilerledikce yeni gorunum
## aciliyor ve ilerlemenin gorunur bir odulu oluyor. Rastgele kutu ya da
## para birimi koymadim -- cocuk oyuncuda kumar mekanigine benzeyen her sey
## hem etik olarak hem magaza politikasi acisindan sorunlu.

const LIST := [
	{
		"id": "kor", "ad_key": "THEME_EMBER", "stars": 0,
		"bg": "#faf3e8", "deep": "#f0e5d4", "grid": "#e2d5c0",
		"idle": "#a9b789", "dark": "#77855c", "ring": "#8f9d6d", "arrow": "#94a07a",
		"lit": "#ffb43d", "core": "#fff6e0", "glow": "#ff9c2b",
		"pulse": "#ff7a45", "tail": "#ffd9a8", "spark": "#e8541f",
		"ink": "#3a322a", "soft": "#8b7f6d", "accent": "#e4664f", "accent_deep": "#b8462f",
	},
	{
		"id": "gece", "ad_key": "THEME_NIGHT", "stars": 15,
		"bg": "#1a1f2e", "deep": "#232a3d", "grid": "#31394f",
		"idle": "#3d4761", "dark": "#2a3145", "ring": "#4d5877", "arrow": "#5a6688",
		"lit": "#5ce1e6", "core": "#e8fdff", "glow": "#3ac9d4",
		"pulse": "#7af0f5", "tail": "#2e5c6b", "spark": "#9df5ff",
		"ink": "#e8eef7", "soft": "#8592ad", "accent": "#f0665f", "accent_deep": "#b8433d",
	},
	{
		"id": "orman", "ad_key": "THEME_FOREST", "stars": 40,
		"bg": "#f2f6ec", "deep": "#e4ecd9", "grid": "#cfdcc0",
		"idle": "#b3c4a0", "dark": "#8fa37c", "ring": "#9ab087", "arrow": "#88a072",
		"lit": "#8fd94a", "core": "#f4ffe6", "glow": "#6fc22e",
		"pulse": "#4fae2a", "tail": "#c3e8a4", "spark": "#3d8f1e",
		"ink": "#2c3a26", "soft": "#71856a", "accent": "#e08b3a", "accent_deep": "#b06720",
	},
	{
		"id": "okyanus", "ad_key": "THEME_OCEAN", "stars": 85,
		"bg": "#eef5f8", "deep": "#dce9f0", "grid": "#c2d7e3",
		"idle": "#a8c2d1", "dark": "#7f9db0", "ring": "#8fadbf", "arrow": "#7d9cb0",
		"lit": "#3fb6e8", "core": "#e8f8ff", "glow": "#1f96cc",
		"pulse": "#0d7fb5", "tail": "#a5dcf2", "spark": "#065b86",
		"ink": "#1e3440", "soft": "#5f7d8d", "accent": "#f0894a", "accent_deep": "#bd6128",
	},
	{
		"id": "seker", "ad_key": "THEME_CANDY", "stars": 150,
		"bg": "#fdf0f6", "deep": "#f7e0ec", "grid": "#eec7dc",
		"idle": "#dfb0c9", "dark": "#c088a5", "ring": "#cf9bb8", "arrow": "#c390ad",
		"lit": "#ff6fb5", "core": "#fff0f7", "glow": "#f04896",
		"pulse": "#b656e8", "tail": "#f7c2e0", "spark": "#8a2fc4",
		"ink": "#40243a", "soft": "#96707f", "accent": "#5ec8d8", "accent_deep": "#37949f",
	},
]


static func by_stars(stars: int) -> Array:
	var out: Array = []
	for t in LIST:
		if stars >= int(t.stars):
			out.append(t)
	return out


static func find(id: String) -> Dictionary:
	for t in LIST:
		if str(t.id) == id:
			return t
	return LIST[0]


## Bir sonraki acilacak tema ve kac yildiz kaldigi. Ilerleme hedefini
## gostermek, aciligi acmaktan daha cok motive ediyor.
static func next_locked(stars: int) -> Dictionary:
	for t in LIST:
		if stars < int(t.stars):
			return {"tema": t, "kalan": int(t.stars) - stars}
	return {}
