//
// App Store Connect metinlerini birlestirir ve SINIRLARI DENETLER.
//
//   node tools/appstore_meta.mjs            (tablo + denetim)
//   node tools/appstore_meta.mjs --yaz      (ayrica dosyaya doker)
//
// NEDEN BU VAR: Apple'in alanlari Play'inkiyle ortusmuyor ve sinirlari
// KARAKTER uzerinden, bayt uzerinden degil. "Tuğla" bes karakter ama
// yedi bayt; elle saymak Turkce, Rusca ve Vietnamca metinlerde
// kacinilmaz olarak yaniltiyor. Bir alan sinirini asarsa App Store
// Connect kaydi kabul etmiyor ve hata on uc dilin hangisinde oldugunu
// soylemiyor.
//
// ACIKLAMA GOVDESI copy.json'dan geliyor, burada TEKRARLANMIYOR: ayni
// metni iki dosyada tutmak, birini guncelleyip otekini unutmak demek.
// Buradaki tek sey App Store'a OZEL alanlar.
//
import {
  readFileSync, mkdirSync, writeFileSync, rmSync, readdirSync,
  copyFileSync, existsSync,
} from "node:fs";
import path from "node:path";

const KOK = path.resolve(path.dirname(new URL(import.meta.url).pathname
  .replace(/^\/([A-Za-z]:)/, "$1")), "..");
const CIKIS = "D:/Temp/mirera-appstore";
const SHOT_BASE = "D:/Temp/mirera-store";

// Apple'in alan sinirlari (karakter).
const SINIR = {
  ad: 30,
  altbaslik: 30,
  anahtar: 100,
  tanitim: 170,
  aciklama: 4000,
};

const copy = JSON.parse(readFileSync(path.join(KOK, "store/copy.json"), "utf8"));
const ek = JSON.parse(readFileSync(path.join(KOK, "store/appstore.json"), "utf8"));

let hata = 0;
const uyar = (m) => { console.error("  HATA: " + m); hata++; };

// Diller iki dosyada da AYNI olmali: birinde olup otekinde olmayan bir
// dil, o dilde magaza sayfasinin yarim kalmasi demek.
const a = Object.keys(copy).sort().join(",");
const b = Object.keys(ek.diller).sort().join(",");
if (a !== b) uyar(`dil kumeleri ayni degil\n    copy.json: ${a}\n    appstore.json: ${b}`);

const satirlar = [];
const cikti = {};

for (const [kod, c] of Object.entries(copy)) {
  const e = ek.diller[kod];
  if (!e) continue;

  const kayit = {
    locale: e.apple,
    name: c.title,
    subtitle: e.altbaslik,
    keywords: e.anahtar,
    promotionalText: e.tanitim,
    description: c.full.trimEnd() + (e.yeni ? "\n\n" + e.yeni : ""),
    privacyPolicyUrl: ek.baglantilar.gizlilik,
    supportUrl: ek.baglantilar.destek,
    marketingUrl: ek.baglantilar.pazarlama,
  };
  cikti[e.apple] = kayit;

  const olc = {
    ad: [...kayit.name].length,
    altbaslik: [...kayit.subtitle].length,
    anahtar: [...kayit.keywords].length,
    tanitim: [...kayit.promotionalText].length,
    aciklama: [...kayit.description].length,
  };
  for (const [alan, n] of Object.entries(olc)) {
    if (n > SINIR[alan]) {
      uyar(`${kod} (${e.apple}) ${alan}: ${n} karakter, sinir ${SINIR[alan]}`);
    }
  }

  // Anahtar kelimelerde VIRGULDEN SONRA BOSLUK yazmak bosa karakter
  // harciyor: Apple virgulu ayirac sayiyor, bosluk ise sayiliyor.
  if (/,\s/.test(kayit.keywords)) {
    uyar(`${kod}: anahtar kelimelerde virgulden sonra bosluk var`);
  }
  // Ad ve alt baslikta gecen kelimeler Apple tarafindan ZATEN
  // dizinleniyor; anahtar kelimede tekrarlamak yeri bosa harciyor.
  const sozcukler = new Set(
    (kayit.name + " " + kayit.subtitle).toLowerCase()
      .split(/[^\p{L}\p{N}]+/u).filter((w) => w.length > 3));
  const tekrar = kayit.keywords.split(",")
    .map((k) => k.trim().toLowerCase())
    .filter((k) => sozcukler.has(k));
  if (tekrar.length) {
    console.warn(`  NOT: ${kod} anahtar kelimesi ad/alt baslikta zaten var:`
      + ` ${tekrar.join(", ")}`);
  }

  satirlar.push([e.apple.padEnd(6), String(olc.ad).padStart(3),
    String(olc.altbaslik).padStart(3), String(olc.anahtar).padStart(4),
    String(olc.tanitim).padStart(4), String(olc.aciklama).padStart(5)].join(" "));
}

console.log("\n  dil     ad alt anah tani aciklama");
console.log("  " + "-".repeat(38));
for (const s of satirlar) console.log("  " + s);
console.log(`  sinir   ${SINIR.ad}  ${SINIR.altbaslik} ${SINIR.anahtar}`
  + `  ${SINIR.tanitim}    ${SINIR.aciklama}\n`);

if (process.argv.includes("--yaz")) {
  mkdirSync(CIKIS, { recursive: true });
  for (const [loc, k] of Object.entries(cikti)) {
    writeFileSync(path.join(CIKIS, loc + ".json"),
      JSON.stringify(k, null, 2) + "\n", "utf8");
  }
  writeFileSync(path.join(CIKIS, "_tumu.json"),
    JSON.stringify(cikti, null, 2) + "\n", "utf8");
  console.log(`  ${Object.keys(cikti).length} dil -> ${CIKIS}\n`);
}

//
// FASTLANE AGACI. `deliver` metni ve gorselleri klasor yapisindan
// okuyor: her dil icin bir klasor, her alan icin bir .txt.
//
// NEDEN FASTLANE: App Store Connect API'sine ekran goruntusu yuklemek
// uc adimli bir protokol (yer ayirt, parcali yukle, saglama ile
// onayla) ve on uc dil x bes goruntu icin bunu elle yazmak, test
// edilmesi zor bir yukleyici yazmak demek. `deliver` bu isi zaten
// yapiyor ve macOS kosucusunda hazir duruyor.
//
// Agac URETILIYOR, elle tutulmuyor: tek kaynak store/copy.json ve
// store/appstore.json. Elle tutulsaydi on uc dil x sekiz dosya =
// 104 dosyayi guncel tutmak gerekirdi.
if (process.argv.includes("--fastlane")) {
  const kok = path.join(KOK, "fastlane");
  // Her kosuda sifirdan: silinen bir dil agacta kalirsa `deliver`
  // onu da yuklemeye calisir.
  rmSync(path.join(kok, "metadata"), { recursive: true, force: true });
  rmSync(path.join(kok, "screenshots"), { recursive: true, force: true });

  let gorsel = 0;
  for (const [loc, k] of Object.entries(cikti)) {
    const md = path.join(kok, "metadata", loc);
    mkdirSync(md, { recursive: true });
    const yaz = (ad, deger) =>
      writeFileSync(path.join(md, ad + ".txt"), deger + "\n", "utf8");
    yaz("name", k.name);
    yaz("subtitle", k.subtitle);
    yaz("keywords", k.keywords);
    yaz("promotional_text", k.promotionalText);
    yaz("description", k.description);
    yaz("support_url", k.supportUrl);
    yaz("marketing_url", k.marketingUrl);
    yaz("privacy_url", k.privacyPolicyUrl);
    // Ilk surumde "yenilikler" alani YOK; `deliver` bos dosyayi da
    // yukluyor ve App Store Connect bos metni reddediyor.

    // Ekran goruntuleri: uretici bizim dil kodlarimizla yaziyor
    // (ios-tr), Apple ise kendi kodlariyla istiyor (tr).
    const kaynakKod = Object.entries(ek.diller)
      .find(([, v]) => v.apple === loc)[0];
    const kaynak = `${SHOT_BASE}/ios-${kaynakKod}`;
    const hedef = path.join(kok, "screenshots", loc);
    if (!existsSync(kaynak)) {
      uyar(`${loc}: ekran goruntusu klasoru yok (${kaynak})`);
      continue;
    }
    mkdirSync(hedef, { recursive: true });
    for (const f of readdirSync(kaynak).filter((f) => f.endsWith(".jpg"))) {
      copyFileSync(path.join(kaynak, f), path.join(hedef, f));
      gorsel++;
    }
  }
  console.log(`  fastlane agaci: ${Object.keys(cikti).length} dil,`
    + ` ${gorsel} ekran goruntusu -> fastlane/\n`);
}

if (hata > 0) {
  console.error(`  ${hata} HATA\n`);
  process.exit(1);
}
console.log("  butun alanlar sinirlarin icinde\n");
