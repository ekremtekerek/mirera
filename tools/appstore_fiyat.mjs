//
// FIYAT (ucretsiz) VE ULKE KULLANILABILIRLIGI.
//
//   node tools/appstore_fiyat.mjs            (yazar)
//   node tools/appstore_fiyat.mjs --durum    (yalnizca okur)
//
// App Store Connect'te bunlar "Pricing and Availability" sayfasinda yan
// yana duruyor ama API'de iki ayri surumde iki ayri kaynak:
//
//   fiyat          -> v1/appPriceSchedules
//   ulkeler        -> v2/appAvailabilities
//
// FIYAT PROGRAMI TUHAF BIR GOVDE ISTIYOR. Fiyatin kendisi `included`
// icinde gecici bir kimlikle tanimlaniyor, `relationships` o gecici
// kimligi gosteriyor ve sunucu ikisini birlestiriyor. Dogrudan
// `appPricePoints` iliskisi vermek kabul edilmiyor.
//
// BEDAVA FIYAT NOKTASI "0.0", "0.00" DEGIL. Dizeyi "0.00" ile
// karsilastiran bir filtre 801 fiyat noktasinin hepsini eliyor ve
// "bedava yok" diyor.
//
import { api, UYGULAMA } from "./asc_api.mjs";

const TEMEL_ULKE = "USA";
const yalnizDurum = process.argv.includes("--durum");

async function bedavaNokta() {
  const r = await api("GET",
    `v1/apps/${UYGULAMA}/appPricePoints?filter%5Bterritory%5D=${TEMEL_ULKE}&limit=10`);
  const b = r.data.find((x) => Number(x.attributes.customerPrice) === 0);
  if (!b) throw new Error("bedava fiyat noktasi bulunamadi");
  return b.id;
}

async function mevcutFiyat() {
  try {
    const r = await api("GET",
      `v1/appPriceSchedules/${UYGULAMA}/manualPrices?limit=10`
      + "&include=appPricePoint");
    return (r.included || []).map((x) => x.attributes?.customerPrice).filter(Boolean);
  } catch {
    return [];
  }
}

///
/// ULKE DURUMUNU OKUMAK ICIN GUVENILIR BIR UC YOK.
///
/// `v2/apps/<id>/appAvailability` -- hem bu uygulamada hem Arcera'da,
/// include'li ve include'siz, her limit degeriyle 404 donuyor:
/// "The path provided does not match a defined resource type."
/// YAZMA ucu (`POST v2/appAvailabilities`) sorunsuz calisiyor, yani
/// kaynak var; okuma yolu belgelendigi gibi davranmiyor.
///
/// Bu yuzden durum, uygulamanin GONDERIME HAZIR olup olmamasindan
/// dolayli olarak anlasiliyor: ulkeler ayarlanmamissa App Store
/// Connect "Add for Review"i zaten reddediyor.
async function ulkeDurumu() {
  try {
    const r = await api("GET", `v2/apps/${UYGULAMA}/appAvailability`
      + "?include=territoryAvailabilities&limit%5BterritoryAvailabilities%5D=50");
    const acik = (r.included || []).filter((x) => x.attributes?.available);
    return {
      yeniUlkeler: r.data.attributes.availableInNewTerritories,
      acik: acik.length,
    };
  } catch {
    return "okunamiyor (yazma ucu calisiyor; bkz. aciklama)";
  }
}

if (yalnizDurum) {
  console.log("fiyat  :", (await mevcutFiyat()).join(", ") || "(ayarlanmamis)");
  console.log("ulkeler:", JSON.stringify(await ulkeDurumu()));
  process.exit(0);
}

// ----------------------------------------------------------------- fiyat

const nokta = await bedavaNokta();
await api("POST", "v1/appPriceSchedules", {
  data: {
    type: "appPriceSchedules",
    relationships: {
      app: { data: { type: "apps", id: UYGULAMA } },
      baseTerritory: { data: { type: "territories", id: TEMEL_ULKE } },
      manualPrices: { data: [{ type: "appPrices", id: "${yeni}" }] },
    },
  },
  included: [{
    type: "appPrices",
    id: "${yeni}",
    relationships: {
      appPricePoint: { data: { type: "appPricePoints", id: nokta } },
    },
  }],
});
console.log(`fiyat: ucretsiz (temel ulke ${TEMEL_ULKE})`);

// --------------------------------------------------------------- ulkeler

// Butun ulkeler aciliyor. `availableInNewTerritories: true` onemli:
// Apple yeni bir ulke ekledinde uygulama orada da kendiliginden
// yayinlaniyor, elle takip gerekmiyor.
const ulkeler = [];
let imlec = "";
for (let i = 0; i < 10; i++) {
  const r = await api("GET",
    `v1/territories?limit=200${imlec ? `&cursor=${imlec}` : ""}`);
  for (const t of r.data) ulkeler.push(t.id);
  imlec = r.meta?.paging?.nextCursor || "";
  if (!imlec) break;
}

await api("POST", "v2/appAvailabilities", {
  data: {
    type: "appAvailabilities",
    attributes: { availableInNewTerritories: true },
    relationships: {
      app: { data: { type: "apps", id: UYGULAMA } },
      // SATIR ICI KIMLIK `${...}` BICIMINDE OLMALI. Gercek bir kimlik
      // (ornegin "6822205137_AFG") su hatayla reddediliyor:
      //   the id must be a local id with the format '${local-id}'
      // Bu kimlikler yalnizca govdenin iki yarisini baglamak icin;
      // sunucu kendi kimliklerini kendisi uretiyor.
      territoryAvailabilities: {
        data: ulkeler.map((t) => ({ type: "territoryAvailabilities", id: "${" + t + "}" })),
      },
    },
  },
  included: ulkeler.map((t) => ({
    type: "territoryAvailabilities",
    id: "${" + t + "}",
    attributes: { available: true },
    relationships: { territory: { data: { type: "territories", id: t } } },
  })),
});
console.log(`ulkeler: ${ulkeler.length} ulke acik, yeni ulkeler kendiliginden`);
