class_name AdProvider
extends Node
##
## Reklam saglayicisinin sozlesmesi. Oyun kodu YALNIZCA bu arayuzu taniyor;
## ne AdMob'u ne sahte saglayiciyi biliyor. Masaustunde gelistirme surerken
## cihazda gercek reklam calisabiliyor, cagri noktalari degismiyor.

signal state_changed

func provider_name() -> String: return "temel"
func initialize(_consent_mode: String) -> void: pass
func is_interstitial_ready() -> bool: return false
func is_rewarded_ready() -> bool: return false
func show_interstitial() -> bool: return false
func show_rewarded() -> bool: return false
