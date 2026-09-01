extends Node
##
## Uygulama ici satin alma (autoload: Store).
##
## TUKETILEBILIR ile TEK SEFERLIK arasindaki fark kritik, cunku HATA
## MODLARI farkli:
##
##   `no_ads` TEK SEFERLIK. PURCHASED gorulunce hemen veriliyor (bayrak set
##   etmek etkisiz-tekrarlanabilir), sonra ONAYLANIYOR. Uc gun icinde
##   onaylanmayan satin almayi Google GERI ODUYOR ve iptal ediyor.
##
##   `hints_*` TUKETILEBILIR. Urun YALNIZCA tuketim basarili donunce
##   veriliyor. Boylece cift verme imkansiz: tuketim basarisizsa satin alma
##   Play'de "sahip olunan" kalir ve sonraki query_purchases tekrar dener.
##
## HALA EKSIK: dogrulama sunucuda yapilmiyor. `Save.ads_removed` kok erisimi
## olan cihazda duzenlenebilir. Dusuk bedelli oyun icin kabul edilebilir ama
## gercek koruma sunucu tarafi dogrulamadir.

signal purchased(product_id: String)

##
## Satilan urunler.
##
## MIRERA'DA TEK URUN VAR. Fusera'dan gelen `hints_10` KALDIRILDI:
## burada ipucu cuzdani yok, ipucu odullu reklamdan geliyor ve `_grant`
## onu hicbir seye cevirmiyordu. Yani urun magazada acilsa oyuncu para
## verip hicbir sey almayacakti -- hem politika ihlali hem de fark
## edilmesi zor bir hata, cunku kod derleniyor ve oyun calisiyor.
##
## Kural: buraya eklenen HER urunun `_grant` icinde bir karsiligi
## olmali. `t_urun_karsiligi()` testi bunu zorluyor.
const PRODUCTS := {
	"no_ads": {"kind": "non_consumable", "fallback": "₺129,00"},
}

var busy := false

var _billing: Object = null
var _ready_to_buy := false
var _prices := {}
var _pending := {}          ## jeton -> urun kimligi
var _flow: Object = null


class Waiter extends RefCounted:
	signal done(ok: bool)
	var _resolved := false
	func resolve(v: bool) -> void:
		if _resolved: return
		_resolved = true
		done.emit(v)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start()


func _start() -> void:
	# Reklam katmanindaki dersin aynisi: CALISMA ZAMANI kaydini soruyoruz.
	if not Engine.has_singleton("GodotGooglePlayBilling"):
		print("[iap] eklenti yok -- sahte saglayici")
		return
	var script := load("res://addons/GodotGooglePlayBilling/BillingClient.gd")
	if script == null:
		return
	_billing = script.new()
	_billing.connected.connect(_on_connected)
	_billing.query_product_details_response.connect(_on_products)
	_billing.query_purchases_response.connect(_on_purchases)
	_billing.on_purchase_updated.connect(_on_updated)
	_billing.consume_purchase_response.connect(_on_consumed)
	_billing.acknowledge_purchase_response.connect(_on_acknowledged)
	_billing.start_connection()
	print("[iap] gercek Billing baglaniyor")


func using_stub() -> bool:
	return _billing == null


## Karar SAF: dogrudan test edilebilsin diye ayri duruyor.
static func offers_allowed(stub: bool, production: bool) -> bool:
	return not stub or not production


## Sahte odeme akisi UYGULAMA MAGAZASINA CIKAMAZ. Reklamdaki kuralin
## aynisi, ayni yonde: unutmak zararsiz tarafa dusuyor.
func offers_enabled() -> bool:
	return offers_allowed(using_stub(), OS.has_feature("liveads"))


func is_owned(id: String) -> bool:
	return Save.ads_removed if id == "no_ads" else false


func price_of(id: String) -> String:
	if _prices.has(id):
		return str(_prices[id])
	return str(PRODUCTS.get(id, {}).get("fallback", "-"))


func purchase(id: String) -> bool:
	if busy or not PRODUCTS.has(id) or is_owned(id):
		return is_owned(id)
	busy = true
	var ok := false
	if _billing != null:
		ok = await _buy_real(id)
	else:
		ok = await _buy_stub(id)
	busy = false
	if ok:
		purchased.emit(id)
	return ok


func _buy_real(id: String) -> bool:
	if not _ready_to_buy:
		return false
	_flow = Waiter.new()
	var launch: Dictionary = _billing.purchase(id)
	if int(launch.get("response_code", -1)) != 0:
		_flow = null
		return false
	# Kullanici odeme ekraninda takilirsa oyun sonsuza kadar askida kalmasin.
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		if _flow != null: _flow.resolve(false))
	var r: bool = await _flow.done
	_flow = null
	return r


## Sahte akis -- yalnizca eklentinin olmadigi derlemelerde.
func _buy_stub(id: String) -> bool:
	await get_tree().create_timer(0.4).timeout
	_grant(id)
	return true


## Satin alimlari geri yukle. Google bu akisi ZORUNLU tutuyor: cihaz
## degistiren kullanici "reklamsiz"i geri alabilmeli.
func restore() -> void:
	if _billing != null:
		_billing.query_purchases(0)          # ProductType.INAPP


# ---------------------------------------------------------- geri cagrilar

func _on_connected() -> void:
	_billing.query_product_details(PackedStringArray(PRODUCTS.keys()), 0)
	# Acilista sessiz geri yukleme: cihaz degistiren kullanici hicbir sey
	# yapmadan reklamsiz haline kavusuyor.
	_billing.query_purchases(0)


func _on_products(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) != 0:
		return
	for p in res.get("product_details", []):
		var id := str(p.get("product_id", p.get("productId", "")))
		var offer: Dictionary = p.get("one_time_purchase_offer_details",
			p.get("oneTimePurchaseOfferDetails", {}))
		var fiyat := str(offer.get("formatted_price", offer.get("formattedPrice", "")))
		if id != "" and fiyat != "":
			_prices[id] = fiyat
	_ready_to_buy = true


func _on_purchases(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) == 0:
		for p in res.get("purchases", []):
			_process_purchase(p)


func _on_updated(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) != 0:
		if _flow != null: _flow.resolve(false)
		return
	for p in res.get("purchases", []):
		_process_purchase(p)


func _process_purchase(p: Dictionary) -> void:
	# PENDING satin alma HENUZ ODENMEMISTIR. Urunu burada vermek bedava
	# dagitmak olur; odeme tamamlaninca Play yeniden haber veriyor.
	if int(p.get("purchase_state", 0)) != 1:      # 1 = PURCHASED
		return
	var token := str(p.get("purchase_token", ""))
	for raw in p.get("product_ids", []):
		var id := str(raw)
		if not PRODUCTS.has(id):
			continue
		if str(PRODUCTS[id].kind) == "consumable":
			_pending[token] = id
			_billing.consume_purchase(token)
		else:
			_grant(id)                             # etkisiz-tekrarlanabilir
			if not bool(p.get("is_acknowledged", false)):
				_billing.acknowledge_purchase(token)
			if _flow != null: _flow.resolve(true)


func _on_consumed(res: Dictionary) -> void:
	var token := str(res.get("token", ""))
	var id := str(_pending.get(token, ""))
	_pending.erase(token)
	if int(res.get("response_code", -1)) != 0:
		if _flow != null: _flow.resolve(false)
		return
	if id != "":
		_grant(id)
	if _flow != null: _flow.resolve(true)


func _on_acknowledged(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) != 0:
		# Onaylanmayan satin almayi Google uc gun sonra GERI ODUYOR.
		# Sonraki acilistaki query_purchases tekrar deneyecek.
		push_warning("[iap] onaylama basarisiz")


func _grant(id: String) -> void:
	if id == "no_ads":
		Save.ads_removed = true
	Save.save_data()
