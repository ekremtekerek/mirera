//
// APP STORE METINLERINI 13 DILE YUKLER.
//
//   node tools/appstore_text.mjs            (hepsi)
//   node tools/appstore_text.mjs en tr      (secili diller)
//   node tools/appstore_text.mjs --durum    (yalnizca durumu yazar)
//
// NEDEN `fastlane deliver` DEGIL: deliver metni DOSYA AGACINDAN okuyor
// (fastlane/metadata/<dil>/<alan>.txt) ve ekran goruntulerini de ayni
// agactan aliyor. Bu, 13 dil x 8 alan = 104 metin dosyasini ve 78 ekran
// goruntusunu DEPOYA koymak demek. Arcera'da tam olarak bu, 13 MB'lik
// magaza goruntusunun oyun paketine (.pck) sizmasina yol acti ve ancak
// CI gunlugu satir satir okunurken fark edildi.
//
// Burada tek kaynak store/copy.json + store/appstore.json; metin
// dogrudan API'ye gidiyor, depoya hicbir sey dusmuyor.
//
// IKI AYRI KAYNAK, kolayca karistiriliyor:
//
//   appInfoLocalizations        -> ad, alt baslik, gizlilik adresi
//                                  (SURUME DEGIL UYGULAMAYA bagli)
//   appStoreVersionLocalizations-> aciklama, anahtar kelimeler, tanitim
//                                  metni, destek ve pazarlama adresi
//
// Ad ve alt basligi surum yerellestirmesine yazmaya calismak
// "attribute is not valid" ile 409 donuyor ve hangi alanin yanlis
// oldugunu soylemiyor.
//
import fs from "node:fs";
import path from "node:path";
import { api, jeton, UYGULAMA, SURUM } from "./asc_api.mjs";

const KOK = path.resolve(path.dirname(new URL(import.meta.url).pathname
  .replace(/^\/([A-Za-z]:)/, "$1")), "..");

const copy = JSON.parse(fs.readFileSync(path.join(KOK, "store/copy.json"), "utf8"));
const ek = JSON.parse(fs.readFileSync(path.join(KOK, "store/appstore.json"), "utf8"));

const argv = process.argv.slice(2);
const yalnizDurum = argv.includes("--durum");
const istenen = argv.filter((a) => !a.startsWith("--"));
const liste = istenen.length ? istenen : Object.keys(ek.diller);

// ------------------------------------------------------------- kaynaklar

/// Duzenlenebilir appInfo: uygulamanin yayindaki kaydi degil, uzerinde
/// calistigimiz olani istiyoruz.
async function appInfoKimligi() {
  const r = await api("GET", `v1/apps/${UYGULAMA}/appInfos?limit=10`);
  const d = r.data.find((x) => x.attributes.state === "PREPARE_FOR_SUBMISSION")
    || r.data[0];
  if (!d) throw new Error("appInfo bulunamadi");
  return d.id;
}

async function surumKimligi() {
  const r = await api("GET",
    `v1/apps/${UYGULAMA}/appStoreVersions?limit=10`
    + "&fields%5BappStoreVersions%5D=versionString,appStoreState");
  const s = r.data.find((x) => x.attributes.versionString === SURUM);
  if (!s) throw new Error(`surum ${SURUM} bulunamadi`);
  return s;
}

///
/// Dil basina kayit: varsa PATCH, yoksa POST. Apple ikisini ayri
/// uclarda tutuyor ve olmayan kaydi PATCH etmek 404 donuyor.
///
/// YENI BIR DILI APP INFO'YA EKLEMEK, SURUM YERELLESTIRMESINI DE
/// KENDILIGINDEN ACIYOR. Yani elimizdeki "mevcut" haritasi bir dil
/// yazildiktan sonra bayatliyor ve sonraki POST su hatayla donuyor:
///
///   409: Entity with locale: tr already exists. Try updating.
///
/// Bastan iki kez okumak yarisi kapatmiyor (Apple kaydi biz ikinci
/// listeyi aldiktan SONRA aciyor). O yuzden cakismada listeyi tazeleyip
/// PATCH'e dusuyoruz.
async function yaz(tur, kapAlani, kapId, mevcut, locale, nitelikler, tazele) {
  const id = mevcut.get(locale);
  if (id) {
    await api("PATCH", `v1/${tur}/${id}`, {
      data: { type: tur, id, attributes: nitelikler },
    });
    return "guncellendi";
  }
  try {
    await api("POST", `v1/${tur}`, {
      data: {
        type: tur,
        attributes: { ...nitelikler, locale },
        relationships: { [kapAlani]: { data: { type: `${kapAlani}s`, id: kapId } } },
      },
    });
    return "eklendi";
  } catch (e) {
    if (!/already exists/i.test(e.message)) throw e;
    const yeni = await tazele();
    for (const [k, v] of yeni) mevcut.set(k, v);
    const id2 = mevcut.get(locale);
    if (!id2) throw e;
    await api("PATCH", `v1/${tur}/${id2}`, {
      data: { type: tur, id: id2, attributes: nitelikler },
    });
    return "guncellendi (kendiliginden acilmisti)";
  }
}

async function mevcutlar(yol) {
  const r = await api("GET", yol);
  const m = new Map();
  for (const x of r.data) m.set(x.attributes.locale, x.id);
  return m;
}

// ------------------------------------------------------------------- ana

const appInfo = await appInfoKimligi();
const surum = await surumKimligi();
console.log(`surum ${SURUM} (${surum.attributes.appStoreState})`);

const BILGI_YOL = `v1/appInfos/${appInfo}/appInfoLocalizations?limit=50`
  + "&fields%5BappInfoLocalizations%5D=locale";
const SURUM_YOL = `v1/appStoreVersions/${surum.id}/appStoreVersionLocalizations?limit=50`
  + "&fields%5BappStoreVersionLocalizations%5D=locale";

const bilgiVar = await mevcutlar(BILGI_YOL);
const surumVar = await mevcutlar(SURUM_YOL);

if (yalnizDurum) {
  for (const dil of liste) {
    const apple = ek.diller[dil]?.apple;
    console.log(`  ${apple.padEnd(6)} bilgi:${bilgiVar.has(apple) ? "var" : "YOK"}`
      + `  surum:${surumVar.has(apple) ? "var" : "YOK"}`);
  }
  process.exit(0);
}

let sayi = 0;
for (const dil of liste) {
  const e = ek.diller[dil];
  const c = copy[dil];
  if (!e || !c) { console.error(`  ${dil}: metin eksik`); process.exitCode = 1; continue; }
  const apple = e.apple;

  const d1 = await yaz("appInfoLocalizations", "appInfo", appInfo, bilgiVar, apple, {
    name: c.title,
    subtitle: e.altbaslik,
    privacyPolicyUrl: ek.baglantilar.gizlilik,
  }, () => mevcutlar(BILGI_YOL));

  // `whatsNew` BILEREK gonderilmiyor: ilk surumde App Store bu alani
  // istemiyor ve bos metin kaydi reddettiriyor.
  const d2 = await yaz("appStoreVersionLocalizations", "appStoreVersion",
    surum.id, surumVar, apple, {
      description: c.full.trimEnd() + (e.yeni ? "\n\n" + e.yeni : ""),
      keywords: e.anahtar,
      promotionalText: e.tanitim,
      supportUrl: ek.baglantilar.destek,
      marketingUrl: ek.baglantilar.pazarlama,
    }, () => mevcutlar(SURUM_YOL));

  console.log(`  ${apple.padEnd(6)} ad/altbaslik ${d1}, aciklama ${d2}`);
  sayi++;
  jeton();   // uzun kosularda jeton eskiyor
}

console.log(`\n${sayi} dil tamam`);
