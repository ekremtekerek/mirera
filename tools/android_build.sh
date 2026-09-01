#!/usr/bin/env bash
#
# Android derlemesi. Imza parolasi DEPOYA GIRMIYOR.
#
#   tools/android_build.sh test      -> telefona kurulacak APK (hata ayiklama imzasi)
#   tools/android_build.sh aab       -> test reklamli AAB (ic test / alfa / beta)
#   tools/android_build.sh yayin     -> CANLI reklamli AAB (yalnizca uretim)
#
# NEDEN BU BETIK VAR: Godot'un yayin imzasi ya on ayarin icine ya ortam
# degiskenlerine yaziliyor. On ayara yazmak parolayi `export_presets.cfg`
# icine, yani DEPOYA sokuyor. Burada parola, depo disindaki README'den
# okunup yalnizca bu surece veriliyor; hicbir dosyaya ve hicbir kayda
# yazilmiyor.
#
set -euo pipefail

GODOT="/d/Tools/Godot/Godot_v4.7.1-stable_win64_console.exe"
KEYS="/d/Tools/android-keys"
OUT="D:/Temp/mirera-android"
KOK="$(cd "$(dirname "$0")/.." && pwd)"

kip="${1:-test}"

mkdir -p "$OUT"

if [ "$kip" = "test" ]; then
	exec "$GODOT" --headless --path "$KOK" \
		--export-debug "Android APK (test)" "$OUT/MIRERA-test.apk"
fi

# Yayin imzasi: parola README'den, tek satirlik alan olarak okunuyor.
README="$KEYS/mirera-upload.README.txt"
[ -f "$README" ] || { echo "HATA: $README yok -- anahtar kurulmamis"; exit 1; }
PW="$(sed -n 's/^ *parola *: *//p' "$README" | head -1)"
[ -n "$PW" ] || { echo "HATA: parola README'den okunamadi"; exit 1; }

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYS/mirera-upload.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="mirera-upload"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$PW"

case "$kip" in
	aab)
		# Test reklam birimi. Ic testte KENDI reklamina tiklamak AdMob
		# politikasi ihlali oldugu icin bu on ayarda "liveads" etiketi YOK.
		"$GODOT" --headless --path "$KOK" \
			--export-release "Android AAB" "$OUT/MIRERA.aab"
		;;
	yayin)
		"$GODOT" --headless --path "$KOK" \
			--export-release "Android AAB (yayin)" "$OUT/MIRERA-live.aab"
		;;
	*)
		echo "kullanim: $0 [test|aab|yayin]"; exit 1
		;;
esac
