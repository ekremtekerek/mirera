//
// APP STORE EKRAN GORUNTULERINI YUKLER -- 13 dil, iki cihaz.
//
//   node tools/appstore_shots.mjs --iphone          (hepsi)
//   node tools/appstore_shots.mjs --ipad en tr      (secili diller)
//   node tools/appstore_shots.mjs --iphone --durum
//
// Kareler `godot --path . -- store ios`  /  `-- store ipad` ile
// uretiliyor; cikti D:/Temp/mirera-store/ios-<dil>/ ve ipad-<dil>/.
//
// IPAD SETI ZORUNLU, istege bagli degil. Godot'nun iOS disa aktariminda
// cihaz ailesi secenegi yok; uretilen Xcode projesi EVRENSEL (iPhone +
// iPad). Paket iPad'i de hedefledigi icin App Store Connect "Add for
// Review"i su tek satirla reddediyor:
//
//   You must upload a screenshot for 13-inch iPad displays.
//
// Seti kaldirmak yeni bir derleme ister; goruntuyu uretmek istemez.
//
// NEDEN `fastlane deliver` DEGIL: deliver butun setleri BIRDEN yoneten
// bir arac. iPad'i eklemek icin cagirinca zaten yuklu iPhone
// goruntulerini de silip yeniden yukluyor -- ve goruntuleri depodan
// okudugu icin 78 dosyayi depoya koymak gerekiyor. Burada her set kendi
// basina dolduruluyor, depoya hicbir sey dusmuyor.
//
import fs from "node:fs";
import path from "node:path";
import {
  api, jeton, varlikYukle, surumKimligi, yerellestirmeler, kapBul, dilTablosu,
} from "./asc_api.mjs";

const KOK = path.resolve(path.dirname(new URL(import.meta.url).pathname
  .replace(/^\/([A-Za-z]:)/, "$1")), "..");

const SHOT_BASE = "D:/Temp/mirera-store";

//
// Apple'in gecerli set turleri. iPhone tarafinda APP_IPHONE_61
// 1206x2622 ve 1179x2556 kabul ediyor; iPad tarafinda
// APP_IPAD_PRO_3GEN_129 ("13 inclik iPad") 2048x2732 ve 2064x2752.
//
const CIHAZLAR = {
  iphone: { tur: "APP_IPHONE_61", onek: "ios-", olcu: "1206x2622" },
  ipad: { tur: "APP_IPAD_PRO_3GEN_129", onek: "ipad-", olcu: "2048x2732" },
};

const diller = dilTablosu(KOK);
const argv = process.argv.slice(2);
const yalnizDurum = argv.includes("--durum");

const secim = argv.includes("--ipad") ? "ipad"
  : argv.includes("--iphone") ? "iphone" : null;
if (!secim) {
  console.error("kullanim: node tools/appstore_shots.mjs --iphone|--ipad [dil ...] [--durum]");
  process.exit(2);
}
const cihaz = CIHAZLAR[secim];

const istenen = argv.filter((a) => !a.startsWith("--"));
const liste = istenen.length ? istenen : Object.keys(diller);

const surum = await surumKimligi();
console.log(`surum 1.0 (${surum.attributes.appStoreState})  ${cihaz.tur} ${cihaz.olcu}`);
const yerel = await yerellestirmeler(surum.id);

const yuklenen = [];
for (const dil of liste) {
  const apple = diller[dil]?.apple;
  const yerelId = yerel.get(apple);
  if (!yerelId) { console.error(`  ${dil}: surumde yok`); process.exitCode = 1; continue; }

  const kapId = await kapBul(yerelId, "appScreenshotSet", "screenshotDisplayType", cihaz.tur);

  if (yalnizDurum) {
    const r = await api("GET", `v1/appScreenshotSets/${kapId}/appScreenshots?limit=20`
      + "&fields%5BappScreenshots%5D=assetDeliveryState,fileName");
    const d = r.data.map((x) => x.attributes.assetDeliveryState?.state).join(",") || "bos";
    console.log(`  ${apple.padEnd(6)} ${r.data.length} kare  ${d}`);
    continue;
  }

  const dizin = `${SHOT_BASE}/${cihaz.onek}${dil}`;
  const dosyalar = fs.existsSync(dizin)
    ? fs.readdirSync(dizin).filter((f) => /\.(jpg|png)$/i.test(f)).sort() : [];
  // Apple en az 1, en cok 10 kare aliyor. Sayiyi burada sabitlemiyoruz
  // ama DILLER ARASINDA AYNI olmali: bir dilde dort, otekinde alti kare
  // olan bir urun sayfasi bakimsiz goruunuyor.
  if (dosyalar.length < 1 || dosyalar.length > 10) {
    console.error(`  ${apple}: ${dosyalar.length} kare (1-10 olmali) -- ${dizin}`);
    process.exitCode = 1;
    continue;
  }

  // Sira onemli: urun sayfasinda dosya adi sirasiyla gorunuyor.
  const eski = await api("GET", `v1/appScreenshotSets/${kapId}/appScreenshots?limit=20`);
  for (const x of eski.data) await api("DELETE", `v1/appScreenshots/${x.id}`);

  for (const f of dosyalar) {
    const id = await varlikYukle("appScreenshots", "appScreenshotSet", kapId,
      path.join(dizin, f));
    yuklenen.push([apple, id]);
  }
  console.log(`  ${apple.padEnd(6)} ${dosyalar.length} kare yuklendi`);
  jeton();
}

if (yalnizDurum || !yuklenen.length) process.exit(process.exitCode || 0);

// Apple goruntuleri isliyor; COMPLETE olmadan gonderim yapilamiyor ve
// yanlis olcu de ancak burada ortaya cikiyor.
console.log("\nisleme bekleniyor");
for (let tur = 0; tur < 40; tur++) {
  await new Promise((r) => setTimeout(r, 10000));
  jeton();
  let hazir = 0;
  for (const [apple, id] of yuklenen) {
    const r = await api("GET", `v1/appScreenshots/${id}`
      + "?fields%5BappScreenshots%5D=assetDeliveryState");
    const d = r.data.attributes.assetDeliveryState;
    if (d?.state === "COMPLETE") hazir++;
    else if ((d?.errors || []).length) {
      console.error(`  ${apple}: ${JSON.stringify(d.errors)}`);
      process.exitCode = 1;
    }
  }
  console.log(`  ${hazir}/${yuklenen.length} hazir`);
  if (hazir === yuklenen.length) break;
}
