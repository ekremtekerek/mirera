#!/usr/bin/env bash
#
# Android derlemesi. Imza parolasi DEPOYA GIRMIYOR.
#
#   tools/android_build.sh test      -> telefona kurulacak APK (hata ayiklama imzasi)
#   tools/android_build.sh aab       -> test reklamli AAB (ic test / alfa / beta)
#   tools/android_build.sh yayin     -> CANLI reklamli AAB (yalnizca uretim)
#
# NEDEN BU BETIK VAR (1): Godot'un yayin imzasi ya on ayarin icine ya ortam
# degiskenlerine yaziliyor. On ayara yazmak parolayi `export_presets.cfg`
# icine, yani DEPOYA sokuyor. Burada parola, depo disindaki README'den
# okunup yalnizca bu surece veriliyor; hicbir dosyaya ve hicbir kayda
# yazilmiyor.
#
# NEDEN BU BETIK VAR (2): Bu makinedeki antivirus, Godot ikonlari
# `android/build/res/` altina yazarken dosyayi tarayip yanina
# `icon_foreground.webp~RF42e3a746.TMP` gibi bir artik birakiyor. Android
# kaynak birlestiricisi `res/` icinde .xml/.png disinda dosya gorunce
# derlemeyi kesiyor. Godot da Gradle'in ciktisini yuttugu icin dis aktarim
# HICBIR HATA YAZMADAN bos donuyor -- FOLDERA 1.1.8'i bir gun boyunca boyle
# blokladi. Artik, suepuermeden SONRA (Godot ikonu yazarken) dogdugu icin
# onceden temizlemek yetmiyor. Cozum: Godot basarisiz olursa onun KENDI
# yazdirdigi Gradle komutunu log'dan alip, artiklari siliip yeniden
# calistiriyoruz. Komut log'dan okundugu icin eklenti listesi degisince
# de dogru kalir.
#
set -euo pipefail

GODOT="/d/Tools/Godot/Godot_v4.7.1-stable_win64_console.exe"
KEYS="/d/Tools/android-keys"
OUT="D:/Temp/mirera-android"
KOK="$(cd "$(dirname "$0")/.." && pwd)"
CIKTI="$KOK/android/build/build/outputs"

kip="${1:-test}"
mkdir -p "$OUT"

suepuer() {
	[ -d "$KOK/android/build/res" ] || return 0
	find "$KOK/android/build/res" -type f \( -name '*.TMP' -o -name '*.tmp' \) -delete 2>/dev/null || true
}

# Godot'un yazdirdigi Gradle komutunu bir .bat'a dokup calistirir.
# `|` iceren argumanlar tirnaklanmali: cmd.exe onlari boru sanip komutu boler.
kurtar() {
	local log="$1" bat pw
	local ham java sdk ilk kalan
	ham="$(grep -A 1 'Build Android project using gradle command:' "$log" | tail -1 | tr -d '\r')"
	[ -n "$ham" ] || { echo "HATA: Gradle komutu log'da bulunamadi"; return 1; }
	java="$(sed -n 's/^Java sdk path: *//p' "$log" | tail -1 | tr -d '\r')"
	sdk="$(sed -n 's/^Updating ANDROID_HOME environment to *//p' "$log" | tail -1 | tr -d '\r')"

	ilk="$(printf '%s' "$ham" | cut -d' ' -f1 | tr '/' '\')"
	kalan=""
	for t in $(printf '%s' "$ham" | cut -d' ' -f2-); do
		case "$t" in
			*'|'*) kalan="$kalan \"$t\"" ;;
			*)     kalan="$kalan $t" ;;
		esac
	done

	pw="$(parola)"
	bat="$(mktemp -u "${TMPDIR:-/d/Temp}/gradle_XXXXXX").bat"
	{
		printf '@echo off\n'
		printf 'set "JAVA_HOME=%s"\n' "$(printf '%s' "$java" | tr '/' '\')"
		printf 'set "ANDROID_HOME=%s"\n' "$(printf '%s' "$sdk" | tr '/' '\')"
		printf 'call "%s"%s "-Prelease_keystore_file=%s" -Prelease_keystore_alias=%s "-Prelease_keystore_password=%%KSPW%%"\n' \
			"$ilk" "$kalan" "$KEYS_WIN/mirera-upload.keystore" "mirera-upload"
		printf 'exit /b %%ERRORLEVEL%%\n'
	} | sed 's/$/\r/' > "$bat"

	suepuer
	KSPW="$pw" "$bat"
	local rc=$?
	rm -f "$bat"
	return $rc
}

parola() {
	local readme="$KEYS/mirera-upload.README.txt"
	[ -f "$readme" ] || { echo "HATA: $readme yok -- anahtar kurulmamis" >&2; exit 1; }
	local p; p="$(sed -n 's/^ *parola *: *//p' "$readme" | head -1)"
	[ -n "$p" ] || { echo "HATA: parola README'den okunamadi" >&2; exit 1; }
	printf '%s' "$p"
}

derle() {
	local preset="$1" hedef="$2" mod="$3" log
	log="$(mktemp -u "${TMPDIR:-/d/Temp}/godot_XXXXXX").log"

	suepuer
	rm -f "$hedef"
	"$GODOT" --headless --verbose --path "$KOK" "$mod" "$preset" "$hedef" > "$log" 2>&1 || true

	if [ ! -s "$hedef" ]; then
		echo "not: Godot sessizce dustu (bilinen antivirus/res artigi), Gradle yeniden calistiriliyor"
		kurtar "$log" || { echo "HATA: Gradle de basarisiz -- log: $log"; exit 1; }
		local uretilen
		uretilen="$(find "$CIKTI" -type f \( -name '*.aab' -o -name '*.apk' \) -newer "$log" | head -1)"
		[ -n "$uretilen" ] || { echo "HATA: Gradle cikti uretmedi -- log: $log"; exit 1; }
		cp "$uretilen" "$hedef"
	fi

	rm -f "$log"
	ls -la "$hedef"
}

KEYS_WIN="D:/Tools/android-keys"

if [ "$kip" = "test" ]; then
	derle "Android APK (test)" "$OUT/MIRERA-test.apk" --export-debug
	exit 0
fi

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYS/mirera-upload.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="mirera-upload"
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(parola)"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD

case "$kip" in
	aab)
		# Test reklam birimi. Ic testte KENDI reklamina tiklamak AdMob
		# politikasi ihlali oldugu icin bu on ayarda "liveads" etiketi YOK.
		derle "Android AAB" "$OUT/MIRERA.aab" --export-release
		;;
	yayin)
		derle "Android AAB (yayin)" "$OUT/MIRERA-live.aab" --export-release
		;;
	*)
		echo "kullanim: $0 [test|aab|yayin]"; exit 1
		;;
esac
