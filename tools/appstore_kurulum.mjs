//
// APP STORE KAYDININ FORM ALANLARI -- kategori, icerik haklari, yas sinifi.
//
//   node tools/appstore_kurulum.mjs            (yazar)
//   node tools/appstore_kurulum.mjs --durum    (yalnizca okur)
//
// App Store Connect arayuzunde bunlar uc ayri sayfada duran uc ayri
// form. API'de de uc ayri kaynak ve ucu de BIRBIRINDEN FARKLI yerde:
//
//   kategori        -> appInfos iliskileri
//   icerik haklari  -> apps.contentRightsDeclaration
//   yas sinifi      -> appInfos/<id>/ageRatingDeclaration
//                      (appStoreVersions ALTINDA DEGIL -- oradan
//                       istemek "The relationship 'ageRatingDeclaration'
//                       does not exist" veriyor)
//
import fs from "node:fs";
import path from "node:path";
import { api, UYGULAMA, SURUM, ANAHTAR_DIZIN } from "./asc_api.mjs";

const KOK = path.resolve(path.dirname(new URL(import.meta.url).pathname
  .replace(/^\/([A-Za-z]:)/, "$1")), "..");

//
// INCELEME ILETISIM BILGILERI DEPONUN DISINDA.
//
// Apple inceleme sirasinda ulasabilmek icin ad, telefon ve e-posta
// istiyor. Depo ozel olsa da kisisel telefon numarasinin kod icinde isi
// yok; anahtarlarla ayni yerde duruyor.
const ILETISIM_YOL = `${ANAHTAR_DIZIN}/iletisim.json`;

//
// YAS SINIFI: 4+.
//
// Oyunda siddet, korku, kumar, kullanici icerigi, sohbet ve
// sinirlandirilmamis web erisimi YOK; hepsi "NONE"/false.
//
// TEK ISTISNA `advertising: true`: oyun ucuncu taraf reklam
// gosteriyor. Bunu "hayir" isaretlemek yas sinifini dusurmuyor ama
// Apple'a yanlis beyan oluyor -- ve inceleyen reklami ilk dakikada
// goruyor.
//
// `lootBox: false`: odullu reklam bir sans kutusu degil, karsiligi
// sabit (bir ipucu).
//
// `ageAssurance` ZORUNLU, varsayilani yok: eksik birakilinca istek
// "You must provide a value for the attribute 'ageAssurance'" ile 409
// donuyor. Oyun yas dogrulamasi yapmiyor.
const YAS = {
  ageAssurance: false,
  advertising: true,
  alcoholTobaccoOrDrugUseOrReferences: "NONE",
  contests: "NONE",
  gambling: false,
  gamblingSimulated: "NONE",
  gunsOrOtherWeapons: "NONE",
  healthOrWellnessTopics: false,
  lootBox: false,
  medicalOrTreatmentInformation: "NONE",
  messagingAndChat: false,
  parentalControls: false,
  profanityOrCrudeHumor: "NONE",
  sexualContentGraphicAndNudity: "NONE",
  sexualContentOrNudity: "NONE",
  socialMedia: false,
  socialMediaAgeRestricted: false,
  horrorOrFearThemes: "NONE",
  matureOrSuggestiveThemes: "NONE",
  unrestrictedWebAccess: false,
  userGeneratedContent: false,
  violenceCartoonOrFantasy: "NONE",
  violenceRealisticProlongedGraphicOrSadistic: "NONE",
  violenceRealistic: "NONE",
  ageRatingOverride: "NONE",
  koreaAgeRatingOverride: "NONE",
};

// Play'de de ayni yerde duruyor: Oyun -> Bulmaca.
const KATEGORI = {
  primaryCategory: "GAMES",
  primarySubcategoryOne: "GAMES_PUZZLE",
  primarySubcategoryTwo: "GAMES_CASUAL",
};

const yalnizDurum = process.argv.includes("--durum");

const bilgi = await api("GET", `v1/apps/${UYGULAMA}/appInfos?limit=10`);
const ai = bilgi.data.find((x) => x.attributes.state === "PREPARE_FOR_SUBMISSION")
  || bilgi.data[0];
if (!ai) throw new Error("appInfo bulunamadi");

if (yalnizDurum) {
  const u = await api("GET", `v1/apps/${UYGULAMA}?fields%5Bapps%5D=contentRightsDeclaration`);
  const k = await api("GET", `v1/appInfos/${ai.id}`
    + "?include=primaryCategory,primarySubcategoryOne,primarySubcategoryTwo");
  const y = await api("GET", `v1/appInfos/${ai.id}/ageRatingDeclaration`);
  console.log("icerik haklari :", u.data.attributes.contentRightsDeclaration);
  for (const [alan] of Object.entries(KATEGORI)) {
    console.log(`${alan.padEnd(22)}:`,
      k.data.relationships[alan]?.data?.id ?? "(bos)");
  }
  const ya = y.data.attributes;
  const farkli = Object.entries(YAS).filter(([k2, v]) => ya[k2] !== v);
  console.log("yas sinifi     :", farkli.length
    ? `${farkli.length} alan farkli: ${farkli.map(([k2]) => k2).join(", ")}`
    : "istenildigi gibi");
  process.exit(0);
}

// 1) Icerik haklari. Oyunun butun gorsel ve sesi kendi uretimi.
await api("PATCH", `v1/apps/${UYGULAMA}`, {
  data: {
    type: "apps",
    id: UYGULAMA,
    attributes: { contentRightsDeclaration: "DOES_NOT_USE_THIRD_PARTY_CONTENT" },
  },
});
console.log("icerik haklari: ucuncu taraf icerik yok");

// 2) Kategoriler. Iliski olarak gidiyor, nitelik olarak degil.
const iliskiler = {};
for (const [alan, deger] of Object.entries(KATEGORI)) {
  iliskiler[alan] = { data: { type: "appCategories", id: deger } };
}
await api("PATCH", `v1/appInfos/${ai.id}`, {
  data: { type: "appInfos", id: ai.id, relationships: iliskiler },
});
console.log(`kategori: ${Object.values(KATEGORI).join(" / ")}`);

// 3) Yas sinifi. Kaynak kimligi appInfo kimligiyle AYNI.
await api("PATCH", `v1/ageRatingDeclarations/${ai.id}`, {
  data: { type: "ageRatingDeclarations", id: ai.id, attributes: YAS },
});
console.log("yas sinifi: 4+ (yalnizca reklam beyan edildi)");

// 4) Inceleme bilgileri. Oyun GIRIS ISTEMIYOR, o yuzden deneme hesabi
// yok; `demoAccountRequired: false` olmazsa Apple hesap bekliyor ve
// gonderim "Information Needed" ile geri geliyor.
if (!fs.existsSync(ILETISIM_YOL)) {
  console.error(`inceleme bilgileri atlandi: ${ILETISIM_YOL} yok`);
  process.exitCode = 1;
} else {
  const kisi = JSON.parse(fs.readFileSync(ILETISIM_YOL, "utf8"));
  const sr = await api("GET",
    `v1/apps/${UYGULAMA}/appStoreVersions?limit=10`
    + "&fields%5BappStoreVersions%5D=versionString");
  const sv = sr.data.find((x) => x.attributes.versionString === SURUM);
  if (!sv) throw new Error(`surum ${SURUM} bulunamadi`);

  //
  // TELIF HAKKI ZORUNLU ve eksikligi yalnizca "Add for Review"da
  // ortaya cikiyor: API'nin gonderim ucu "This resource cannot be
  // reviewed, please check associated errors" diyor ve HANGI alanin
  // eksik oldugunu soylemiyor. App Store Connect arayuzu soyluyor.
  //
  // Bicim Apple'in bekledigi gibi: yil + hak sahibi, "(c)" YOK --
  // Apple onu kendisi ekliyor.
  const yil = new Date().getFullYear();
  await api("PATCH", `v1/appStoreVersions/${sv.id}`, {
    data: {
      type: "appStoreVersions", id: sv.id,
      attributes: { copyright: `${yil} ${kisi.ad} ${kisi.soyad}` },
    },
  });
  console.log(`telif hakki: ${yil} ${kisi.ad} ${kisi.soyad}`);

  //
  // INCELEME NOTLARI.
  //
  // Apple'in "Guideline 2.1 - Information Needed" mektubu bunu ACIKCA
  // istiyor: "add this information to the Notes field of the App Review
  // Information section ... for reference on future submissions". Yani
  // yalnizca Resolution Center'a cevap yazmak yetmiyor, ayni bilgi
  // burada da durmali -- sonraki surumlerde yeniden sorulmasin diye.
  //
  // Metin depoda `store/apple-review-notes.txt` icinde; sinir 4000
  // karakter ve asilirsa Apple kaydi reddediyor.
  const NOT_YOL = path.join(KOK, "store/apple-review-notes.txt");
  let notlar = null;
  if (fs.existsSync(NOT_YOL)) {
    notlar = fs.readFileSync(NOT_YOL, "utf8").trim();
    if ([...notlar].length > 4000) {
      throw new Error(`inceleme notlari ${[...notlar].length} karakter, sinir 4000`);
    }
  }

  const nitelik = {
    contactFirstName: kisi.ad,
    contactLastName: kisi.soyad,
    contactPhone: kisi.telefon,
    contactEmail: kisi.eposta,
    demoAccountRequired: false,
    ...(notlar ? { notes: notlar } : {}),
  };
  const var_ = await api("GET", `v1/appStoreVersions/${sv.id}/appStoreReviewDetail`);
  if (var_?.data?.id) {
    await api("PATCH", `v1/appStoreReviewDetails/${var_.data.id}`, {
      data: { type: "appStoreReviewDetails", id: var_.data.id, attributes: nitelik },
    });
    console.log("inceleme bilgileri: guncellendi");
  } else {
    await api("POST", "v1/appStoreReviewDetails", {
      data: {
        type: "appStoreReviewDetails",
        attributes: nitelik,
        relationships: {
          appStoreVersion: { data: { type: "appStoreVersions", id: sv.id } },
        },
      },
    });
    console.log("inceleme bilgileri: eklendi (giris gerekmiyor)");
  }
}
