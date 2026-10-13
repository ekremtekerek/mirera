//
// APP STORE CONNECT API -- ORTAK KATMAN.
//
// Hem onizleme videosu (appPreviews) hem de ekran goruntusu
// (appScreenshots) ayni uc adimdan geciyor: rezervasyon, parcali PUT,
// MD5 ile onay. Iki arac da burayi kullaniyor ki yukleme mantigi tek
// yerde dursun.
//
// Anahtar deponun DISINDA duruyor ve iceriği hicbir yere basilmiyor.
//
import fs from "node:fs";
import crypto from "node:crypto";
import path from "node:path";

export const ANAHTAR_DIZIN = "D:/Tools/appstore-api";
export const KEY_ID = "NYNRM95D39";
export const ISSUER = "0a7724e0-a9f4-4662-81ff-3142d2bef619";

export const UYGULAMA = "6822283725";
export const SURUM = "1.0";

// Jeton on bes dakika gecerli; uzun yuklemelerde `jeton()` ile
// tazeleniyor. `let` bildirimi `jeton()` cagrisindan ONCE olmali --
// tersi "Cannot access 'JWT' before initialization" veriyor, cunku
// fonksiyon bildirimi yukari cikiyor ama `let` cikmiyor.
let JWT = "";

export function jeton() {
  const p8 = fs.readFileSync(`${ANAHTAR_DIZIN}/AuthKey_${KEY_ID}.p8`, "utf8");
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const t = Math.floor(Date.now() / 1000);
  const bas = b64({ alg: "ES256", kid: KEY_ID, typ: "JWT" });
  const gov = b64({ iss: ISSUER, iat: t, exp: t + 900, aud: "appstoreconnect-v1" });
  const imza = crypto.createSign("SHA256").update(`${bas}.${gov}`)
    .sign({ key: p8, dsaEncoding: "ieee-p1363" }).toString("base64url");
  JWT = `${bas}.${gov}.${imza}`;
  return JWT;
}

jeton();

///
/// SUNUCU HATASINDA YENIDEN DENIYOR.
///
/// Apple'in ucu on uc dillik bir donguDE ara sira su cevabi veriyor:
///
///   500: An unexpected error occurred on the server side.
///
/// Istegin kendisiyle ilgisi yok -- ayni cagri saniyeler sonra 201
/// donuyor. Denemeden dusmek, on uc dilin ortasinda yarim kalmis bir
/// magaza sayfasi birakiyor. 429 (hiz siniri) de ayni sekilde gecici.
///
/// ISTEMCI hatalari (400-499, 429 haric) TEKRARLANMIYOR: onlar bizim
/// govdemizle ilgili ve tekrarlamak ayni hatayi uc kez yazdirmaktan
/// baska bir sey yapmaz.
const YENIDEN = 3;
const BEKLE = 2500;

export async function api(metod, yol, govde) {
  let son = null;
  for (let deneme = 1; deneme <= YENIDEN; deneme++) {
    const ayar = { method: metod, headers: { Authorization: `Bearer ${JWT}` } };
    if (govde !== undefined) {
      ayar.body = JSON.stringify(govde);
      ayar.headers["Content-Type"] = "application/json";
    }
    const r = await fetch(`https://api.appstoreconnect.apple.com/${yol}`, ayar);
    if (r.status === 204) return null;
    const metin = await r.text();
    let veri = null;
    try { veri = JSON.parse(metin); } catch { /* bos govde */ }
    if (r.status < 400) return veri;

    const e = veri?.errors?.[0];
    son = new Error(`${metod} ${yol} -> ${r.status}: `
      + (e?.detail || e?.title || metin.slice(0, 300)));
    const gecici = r.status >= 500 || r.status === 429;
    if (!gecici || deneme === YENIDEN) throw son;
    console.error(`    ${r.status} -- ${deneme}. deneme, yeniden deniyor`);
    await new Promise((f) => setTimeout(f, BEKLE * deneme));
  }
  throw son;
}

/// Rezervasyon + parcali yukleme + onay. `tur` ya "appPreviews" ya da
/// "appScreenshots"; ikisinin govdesi ayni, yalnizca kap adi degisiyor.
export async function varlikYukle(tur, kapTuru, kapId, dosya) {
  const bayt = fs.readFileSync(dosya);
  const ad = path.basename(dosya);

  const rez = await api("POST", `v1/${tur}`, {
    data: {
      type: tur,
      attributes: { fileSize: bayt.length, fileName: ad },
      relationships: { [kapTuru]: { data: { type: `${kapTuru}s`, id: kapId } } },
    },
  });

  const id = rez.data.id;
  for (const op of rez.data.attributes.uploadOperations) {
    const dilim = bayt.subarray(op.offset, op.offset + op.length);
    const basliklar = {};
    for (const h of op.requestHeaders || []) basliklar[h.name] = h.value;
    const r = await fetch(op.url, { method: op.method, headers: basliklar, body: dilim });
    if (!r.ok) throw new Error(`parca yuklenemedi (${op.offset}): ${r.status}`);
  }

  const ozet = crypto.createHash("md5").update(bayt).digest("hex");
  await api("PATCH", `v1/${tur}/${id}`, {
    data: { type: tur, id, attributes: { uploaded: true, sourceFileChecksum: ozet } },
  });
  return id;
}

/// Varlik kutuphanesine gorsel koyar (urun sayfasi basligi, arama
/// sonucu gorseli vb). Ekran goruntusu/onizlemeden FARKLI bir kap:
/// surume degil UYGULAMAYA bagli, ve `category` istiyor.
export async function kutuphaneGorseliYukle(dosya) {
  const bayt = fs.readFileSync(dosya);
  const rez = await api("POST", "v1/appAssetLibraryImages", {
    data: {
      type: "appAssetLibraryImages",
      attributes: {
        fileName: path.basename(dosya),
        fileSize: bayt.length,
        category: "CREATIVE_ASSETS",
      },
      relationships: {
        assetLibrary: { data: { type: "appAssetLibraries", id: UYGULAMA } },
      },
    },
  });

  const id = rez.data.id;
  for (const op of rez.data.attributes.uploadOperations) {
    const dilim = bayt.subarray(op.offset, op.offset + op.length);
    const basliklar = {};
    for (const h of op.requestHeaders || []) basliklar[h.name] = h.value;
    const r = await fetch(op.url, { method: op.method, headers: basliklar, body: dilim });
    if (!r.ok) throw new Error(`parca yuklenemedi (${op.offset}): ${r.status}`);
  }

  // Ekran goruntusu/onizlemeden farkli: bu kaynak `sourceFileChecksum`
  // KABUL ETMIYOR ("is not an attribute on the resource"), yalnizca
  // `uploaded` bekliyor.
  await api("PATCH", `v1/appAssetLibraryImages/${id}`, {
    data: { type: "appAssetLibraryImages", id, attributes: { uploaded: true } },
  });
  return id;
}

export async function surumKimligi() {
  const r = await api("GET",
    `v1/apps/${UYGULAMA}/appStoreVersions?limit=10`
    + "&fields%5BappStoreVersions%5D=versionString,appStoreState");
  const s = r.data.find((x) => x.attributes.versionString === SURUM);
  if (!s) throw new Error(`surum ${SURUM} bulunamadi`);
  return s;
}

export async function yerellestirmeler(surumId) {
  const r = await api("GET",
    `v1/appStoreVersions/${surumId}/appStoreVersionLocalizations?limit=50`
    + "&fields%5BappStoreVersionLocalizations%5D=locale");
  const m = new Map();
  for (const x of r.data) m.set(x.attributes.locale, x.id);
  return m;
}

/// Dil basina bir kap; yoksa aciliyor.
export async function kapBul(yerelId, kapTuru, alan, deger) {
  const liste = await api("GET",
    `v1/appStoreVersionLocalizations/${yerelId}/${kapTuru}s?limit=20`
    + `&fields%5B${kapTuru}s%5D=${alan}`);
  const v = liste.data.find((x) => x.attributes[alan] === deger);
  if (v) return v.id;
  const y = await api("POST", `v1/${kapTuru}s`, {
    data: {
      type: `${kapTuru}s`,
      attributes: { [alan]: deger },
      relationships: {
        appStoreVersionLocalization: {
          data: { type: "appStoreVersionLocalizations", id: yerelId },
        },
      },
    },
  });
  return y.data.id;
}

export function dilTablosu(kok) {
  return JSON.parse(
    fs.readFileSync(path.join(kok, "store/appstore.json"), "utf8")).diller;
}
