//
// PAKETI SURUME BAGLAR VE INCELEMEYE GONDERIR.
//
//   node tools/appstore_gonder.mjs --durum    (ne eksik, yazmadan)
//   node tools/appstore_gonder.mjs --bagla    (paketi surume bagla)
//   node tools/appstore_gonder.mjs --gonder   (incelemeye gonder)
//
// Adimlar BILEREK ayri: "bagla" geri alinabilir, "gonder" alinamaz.
// Tek komutta birlestirmek, yanlis paketi incelemeye yollamayi bir
// yazim hatasi kadar kolaylastirirdi.
//
// IHRACAT UYUMLULUGU. Apple her pakette sifreleme kullanilip
// kullanilmadigini soruyor ve cevaplanmadan gonderim yapilamiyor.
// Oyun yalnizca HTTPS kullaniyor (reklam istekleri); bu, Apple'in
// "muaf" saydigi standart sifreleme. `usesNonExemptEncryption: false`
// tam olarak bunu soyluyor.
//
import { api, UYGULAMA, SURUM } from "./asc_api.mjs";

const argv = process.argv.slice(2);
const durum = argv.includes("--durum");
const bagla = argv.includes("--bagla");
const gonder = argv.includes("--gonder");
if (!durum && !bagla && !gonder) {
  console.error("kullanim: node tools/appstore_gonder.mjs --durum|--bagla|--gonder");
  process.exit(2);
}

const sr = await api("GET", `v1/apps/${UYGULAMA}/appStoreVersions?limit=10`
  + "&fields%5BappStoreVersions%5D=versionString,appStoreState");
const sv = sr.data.find((x) => x.attributes.versionString === SURUM);
if (!sv) throw new Error(`surum ${SURUM} bulunamadi`);
console.log(`surum ${SURUM} (${sv.attributes.appStoreState})`);

// En yeni paket. `processingState` VALID olmadan baglanamiyor; Apple
// yuklemeden sonra birkac dakika isliyor.
// `sort` bu ucta KABUL EDILMIYOR ("The parameter 'sort' can not be used
// with this request"); siralamayi kendimiz yapiyoruz.
const br = await api("GET", `v1/apps/${UYGULAMA}/builds?limit=20`
  + "&fields%5Bbuilds%5D=version,processingState,uploadedDate,expired");
const paketler = br.data
  .filter((b) => !b.attributes.expired)
  .sort((a, b) => String(b.attributes.uploadedDate)
    .localeCompare(String(a.attributes.uploadedDate)));
console.log(`paket sayisi: ${paketler.length}`);
for (const b of paketler.slice(0, 5)) {
  console.log(`  ${b.attributes.version.padEnd(4)} ${b.attributes.processingState}`
    + `  ${b.attributes.uploadedDate}`);
}

const paket = paketler.find((b) => b.attributes.processingState === "VALID");

// Surume bagli paket (varsa).
const bagli = await api("GET", `v1/appStoreVersions/${sv.id}/build`)
  .then((r) => r?.data?.id ?? null).catch(() => null);
console.log(`surume bagli paket: ${bagli ?? "(yok)"}`);

if (durum) {
  if (!paket) console.log("\nislenmis (VALID) paket yok -- derleme bitmemis olabilir");
  else if (!bagli) console.log("\nhazir: --bagla ile baglanabilir");
  else console.log("\nhazir: --gonder ile incelemeye gonderilebilir");
  process.exit(0);
}

if (bagla) {
  if (!paket) throw new Error("islenmis (VALID) paket yok");

  // Ihracat uyumlulugu paketin KENDI alani; surumun degil.
  //
  // Godot urettigi Info.plist'e `ITSAppUsesNonExemptEncryption` yaziyor,
  // yani deger yuklemede ZATEN dolu gelebiliyor. O zaman Apple
  // "You cannot update when the value is already set" ile 409 donuyor
  // ve bu bir hata DEGIL -- istedigimiz sonuc zaten yerinde.
  try {
    await api("PATCH", `v1/builds/${paket.id}`, {
      data: {
        type: "builds", id: paket.id,
        attributes: { usesNonExemptEncryption: false },
      },
    });
    console.log("ihracat uyumlulugu: muaf sifreleme (yalnizca HTTPS)");
  } catch (e) {
    if (!/already set/i.test(e.message)) throw e;
    console.log("ihracat uyumlulugu: paketten geldi, dokunulmadi");
  }

  await api("PATCH", `v1/appStoreVersions/${sv.id}`, {
    data: {
      type: "appStoreVersions", id: sv.id,
      relationships: { build: { data: { type: "builds", id: paket.id } } },
    },
  });
  console.log(`paket ${paket.attributes.version} surume baglandi`);
  process.exit(0);
}

// ----------------------------------------------------------------- gonder

if (!bagli) throw new Error("once --bagla ile paketi baglayin");

// Inceleme gonderimi IKI adim: once kap aciliyor, sonra surum ONA
// ekleniyor, en sonda gonderim "submitted" yapiliyor. Tek POST ile
// gonderilmiyor.
const mevcut = await api("GET", `v1/apps/${UYGULAMA}/reviewSubmissions?limit=10`
  + "&fields%5BreviewSubmissions%5D=state,platform");
let kap = mevcut.data.find((x) => x.attributes.state === "READY_FOR_REVIEW");

if (!kap) {
  const y = await api("POST", "v1/reviewSubmissions", {
    data: {
      type: "reviewSubmissions",
      attributes: { platform: "IOS" },
      relationships: { app: { data: { type: "apps", id: UYGULAMA } } },
    },
  });
  kap = y.data;
  console.log(`inceleme kabi acildi: ${kap.id}`);
} else {
  console.log(`acik inceleme kabi kullaniliyor: ${kap.id}`);
}

// Surum kaba ekleniyor. Zaten ekliyse Apple 409 donuyor; o zararsiz.
try {
  await api("POST", "v1/reviewSubmissionItems", {
    data: {
      type: "reviewSubmissionItems",
      relationships: {
        reviewSubmission: { data: { type: "reviewSubmissions", id: kap.id } },
        appStoreVersion: { data: { type: "appStoreVersions", id: sv.id } },
      },
    },
  });
  console.log("surum gonderime eklendi");
} catch (e) {
  if (!/already/i.test(e.message)) throw e;
  console.log("surum zaten gonderimde");
}

await api("PATCH", `v1/reviewSubmissions/${kap.id}`, {
  data: { type: "reviewSubmissions", id: kap.id, attributes: { submitted: true } },
});
console.log("\nINCELEMEYE GONDERILDI");
