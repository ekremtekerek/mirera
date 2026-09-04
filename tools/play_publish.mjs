#!/usr/bin/env node
//
// Google Play Developer API ile magaza sayfasini ve surumu yayinlar.
//
//   node tools/play_publish.mjs --key D:/Tools/play-api/foldera-sa.json --listings --images
//   node tools/play_publish.mjs --key ... --aab D:/Temp/foldera-android/FOLDERA.aab
//
// NEDEN BU VAR: Play Console arayuzunden 13 dil x 20 gorsel = 260 yerlestirme
// yapmak hem cok uzun hem de gorsel SIRASI kontrol edilemiyor (kutuphane
// secicisi yukleme sirasini karistiriyor). API'de yukleme sirasi = gosterim
// sirasi, yani ilk ekran goruntusu gercekten ilk oluyor -- ASO'da en cok onemli
// olan sey bu.
//
// GUVENLIK FRENI: `production` kanali varsayilan olarak KAPALI. Acmak icin
// komut satirinda acikca `--uretime-cik` yazmak gerekir. Uretim surumu geri
// alinamaz; freni kaza eseri gecilemeyecek kadar zahmetli biraktim.
//
// Bagimlilik yok: JWT imzalama node:crypto ile, istekler yerlesik fetch ile.
//
import { createSign } from 'node:crypto'
import { readFile } from 'node:fs/promises'
import { existsSync, readFileSync, statSync } from 'node:fs'
import path from 'node:path'

const PKG = 'com.mirera.game'
//
// Betikteki paket adi ile on ayarlardaki AYNI mi.
//
// Bu dosyalar birbirinden kopyalanarak turuyor ve `PKG` satirini
// degistirmeyi unutmak, HAZIR BIR AAB I BASKA BIR OYUNUN CANLI
// LISTESINE yuklemek demek. Yukleme basarili olur, hicbir uyari cikmaz.
function paketiDogrula(kokDizin) {
  const yol = path.join(kokDizin, '..', 'export_presets.cfg')
  let metin
  try {
    metin = readFileSync(yol, 'utf8')
  } catch {
    return          // on ayar dosyasi yoksa sessiz gec: bu kontrol bir ek guvence
  }
  const bulunan = [...metin.matchAll(/^package\/unique_name="([^"]+)"/gm)]
    .map((m) => m[1])
  if (bulunan.length === 0) return
  const uyusmayan = bulunan.filter((p) => p !== PKG)
  if (uyusmayan.length > 0) {
    die(
      `paket adi uyusmuyor.\n` +
      `  betikte      : ${PKG}\n` +
      `  on ayarlarda : ${[...new Set(bulunan)].join(', ')}\n` +
      `Yanlis uygulamaya yukleme yapmamak icin duruldu.`
    )
  }
}
const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3'
const UPLOAD = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3'
const ALLOWED_TRACKS = new Set(['internal', 'alpha', 'beta'])

// store/<klasor> -> Play dil kodu.  Play kendi kodlarini istiyor; "tr" degil
// "tr-TR", "pt" degil "pt-BR". Yanlis kod sessizce yok sayilmiyor, hata veriyor.
const LOCALES = {
  en: 'en-US', tr: 'tr-TR', es: 'es-ES', pt: 'pt-BR', de: 'de-DE',
  fr: 'fr-FR', it: 'it-IT', ru: 'ru-RU', pl: 'pl-PL', nl: 'nl-NL',
  id: 'id', vi: 'vi', uk: 'uk',
}

// Gorsel tipi -> o tipe girecek dosyalar (SIRA ONEMLI).
// Mirera'da gorseller uretildikleri yerde duruyor (depoya girmiyorlar,
// tamamen yeniden uretilebilirler): posterler dil klasorlerinde, ikon ve
// one cikan gorsel ayri klasorde. `dir` = <shots>/<dil>, `root` = ikon kokú.
const IMAGES = (dir, root) => ({
  icon: [path.join(root, 'icon-512.png')],
  featureGraphic: [path.join(root, `feature-1024x500-${path.basename(dir)}.png`)],
  phoneScreenshots: shots(dir),
  sevenInchScreenshots: shots(dir),
  tenInchScreenshots: shots(dir),
})
const shots = (dir) =>
  ['01', '02', '03', '04', '05'].map((n) => path.join(dir, `${n}.png`))

// ------------------------------------------------------------------ yardimci

const args = process.argv.slice(2)
const flag = (name) => args.includes(`--${name}`)
const opt = (name, dflt = null) => {
  const i = args.indexOf(`--${name}`)
  return i >= 0 && args[i + 1] ? args[i + 1] : dflt
}

function die(msg) {
  console.error(`\n  HATA: ${msg}\n`)
  process.exit(1)
}

async function token(keyPath) {
  const sa = JSON.parse(await readFile(keyPath, 'utf8'))
  if (!sa.client_email || !sa.private_key) die(`${keyPath} bir servis hesabi anahtari degil`)
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url')
  const now = Math.floor(Date.now() / 1000)
  const head = b64({ alg: 'RS256', typ: 'JWT' })
  const claim = b64({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now, exp: now + 3600,
  })
  const signer = createSign('RSA-SHA256')
  signer.update(`${head}.${claim}`)
  const assertion = `${head}.${claim}.${b64url(signer.sign(sa.private_key))}`
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion,
    }),
  })
  const body = await res.json()
  if (!res.ok) die(`token alinamadi: ${JSON.stringify(body)}`)
  console.log(`  kimlik: ${sa.client_email}`)
  return body.access_token
}
const b64url = (buf) => Buffer.from(buf).toString('base64url')

// Play'in gorsel ucu toplu yuklemede ara sira 500 donuyor -- istegin kendisinde
// bir sorun yok, tekrar denenince geciyor. 260 gorselluk bir kosuda bunun bir
// kez olmasi neredeyse kesin, o yuzden yeniden deneme betigin icinde.
const RETRYABLE = new Set([429, 500, 502, 503, 504])
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

async function call(tok, method, url, { json, body, type } = {}) {
  const headers = { authorization: `Bearer ${tok}` }
  let payload = body
  if (json !== undefined) {
    headers['content-type'] = 'application/json'
    payload = JSON.stringify(json)
  } else if (type) {
    headers['content-type'] = type
  }
  let last = ''
  for (let attempt = 1; attempt <= 5; attempt++) {
    let res
    try {
      res = await fetch(url, { method, headers, body: payload })
    } catch (e) {
      last = `${res ? res.status : 'ag'} ${e.message}`
      if (attempt === 5) break
      await sleep(1000 * 2 ** attempt)
      continue
    }
    const text = await res.text()
    if (res.ok) return text ? JSON.parse(text) : {}
    last = `${res.status} ${text.slice(0, 400)}`
    if (!RETRYABLE.has(res.status) || attempt === 5) break
    console.log(`     ${res.status} geldi, ${attempt}. deneme yeniden...`)
    await sleep(1000 * 2 ** attempt)
  }
  die(`${method} ${url.replace(UPLOAD, '').replace(API, '')}\n  ${last}`)
}

// --------------------------------------------------------------------- akis

const keyPath = opt('key')
if (!keyPath) die('--key <servis-hesabi.json> gerekli')
if (!existsSync(keyPath)) die(`anahtar bulunamadi: ${keyPath}`)

const root = opt('shots', 'D:/Temp/mirera-store')
const ikonKok = opt('ikonlar', 'D:/Temp/mirera-icons')
// Metinler DEPODA (surumleniyor), gorseller uretim klasorunde (uretilebilir).
const metinKok = opt('metinler', 'D:/Projects/mirera/store')
const track = opt('track', 'internal')
// Uretim kanali hala VARSAYILAN OLARAK KAPALI. Acmak icin komut satirinda
// acikca `--uretime-cik` yazmak gerekiyor; kaza eseri yazilacak bir sey degil.
//
// Guard'i tamamen kaldirmadim cunku amaci hala gecerli: bir betik kosusunun
// yanlislikla milyonlarca kullaniciya surum itmesini engellemek. Degisen sey,
// kasitli bir uretim cikisinin artik MUMKUN olmasi -- hesap sahibi istedi.
if (track === 'production' && !flag('uretime-cik')) {
  die('uretim kanali icin `--uretime-cik` bayragi gerekli.\n' +
      '  Bu kasten zahmetli: uretim surumu geri alinamaz, milyonlarca kullaniciya gider.')
}
if (!ALLOWED_TRACKS.has(track) && track !== 'production') {
  die(`bilinmeyen kanal "${track}". Izinli: ${[...ALLOWED_TRACKS].join(', ')}, production.`)
}
const relStatus = flag('taslak-surum') ? 'draft' : 'completed'
// Surum notlari dosyadan: {dil-kodu: metin}
const notesPath = opt('notlar')
const notes = notesPath ? JSON.parse(await readFile(notesPath, 'utf8')) : null
// Magaza videosu. Play'in kabul ettigi tek bicim `youtube.com/watch?v=<id>`.
// Kullanici elindeki adresi Shorts olarak verirse sessizce reddedilmesin diye
// kimligi cikarip dogru bicime ceviriyoruz.
const videoUrl = (() => {
  const raw = opt('video')
  if (!raw) return null
  const m = raw.match(/(?:v=|\/shorts\/|youtu\.be\/|\/embed\/)([A-Za-z0-9_-]{11})/)
  if (!m) die(`video adresinden YouTube kimligi cikarilamadi: ${raw}`)
  return `https://www.youtube.com/watch?v=${m[1]}`
})()
const aab = opt('aab')
const privacyUrl = opt('privacy')
const doListings = flag('listings')
const doImages = flag('images')
if (!doListings && !doImages && !aab) {
  die('yapilacak is yok. --listings, --images ve/veya --aab <dosya> ver.')
}

paketiDogrula(metinKok)

console.log(`\nMIRERA -> Google Play  (${PKG})`)
const tok = await token(keyPath)

const edit = await call(tok, 'POST', `${API}/applications/${PKG}/edits`)
console.log(`  duzenleme acildi: ${edit.id}\n`)
const E = `${API}/applications/${PKG}/edits/${edit.id}`
const EU = `${UPLOAD}/applications/${PKG}/edits/${edit.id}`

const copy = JSON.parse(await readFile(path.join(metinKok, 'copy.json'), 'utf8'))

if (doListings) {
  for (const [dir, lang] of Object.entries(LOCALES)) {
    const c = copy[dir]
    if (!c) die(`copy.json icinde "${dir}" yok`)
    if (c.title.length > 30) die(`${dir}: baslik ${c.title.length} karakter (en fazla 30)`)
    if (c.short.length > 80) die(`${dir}: kisa aciklama ${c.short.length} karakter (en fazla 80)`)
    await call(tok, 'PUT', `${E}/listings/${lang}`, {
      json: {
        language: lang,
        title: c.title,
        shortDescription: c.short,
        fullDescription: c.full,
        // Play YALNIZCA `youtube.com/watch?v=...` bicimini kabul ediyor;
        // Shorts (`/shorts/<id>`) ve kisa (`youtu.be/...`) baglantilar
        // reddediliyor. `--video` ile verilen adres burada normallestiriliyor.
        video: videoUrl || undefined,
      },
    })
    console.log(`  metin  ${lang.padEnd(6)} ${c.title}`)
  }
  console.log()
}

if (doImages) {
  const units = []
  for (const [dir, lang] of Object.entries(LOCALES)) {
    const set = IMAGES(path.join(root, dir), ikonKok)
    for (const [type, files] of Object.entries(set)) units.push({ lang, type, files })
  }
  for (const u of units) for (const f of u.files) if (!existsSync(f)) die(`gorsel yok: ${f}`)

  // Her birim (dil + gorsel tipi) KENDI ICINDE sirali kaliyor: Play'de yukleme
  // sirasi = gosterim sirasi ve ilk ekran goruntusu gercekten ilk olmali.
  // Paralellik yalnizca birimler ARASINDA -- 260 gorseli tek tek yuklemek 10
  // dakikayi asiyor ve calisma penceresine sigmiyordu.
  const CONC = 5
  let next = 0
  let done = 0
  const worker = async () => {
    while (next < units.length) {
      const u = units[next++]
      // Once temizle: aksi halde her kosuda ustune ekleyip 8 sinirini asiyor.
      await call(tok, 'DELETE', `${E}/listings/${u.lang}/${u.type}`)
      for (const f of u.files) {
        await call(tok, 'POST', `${EU}/listings/${u.lang}/${u.type}?uploadType=media`, {
          body: await readFile(f), type: 'image/png',
        })
      }
      done++
      console.log(`  gorsel ${u.lang.padEnd(6)} ${u.type.padEnd(21)} ${String(u.files.length).padStart(2)}   ${done}/${units.length}`)
    }
  }
  await Promise.all(Array.from({ length: CONC }, worker))
  console.log()
}

if (aab) {
  if (!existsSync(aab)) die(`AAB bulunamadi: ${aab}`)
  const mb = (statSync(aab).size / 1048576).toFixed(1)
  console.log(`  AAB yukleniyor (${mb} MB) -- birkac dakika surebilir...`)
  const up = await call(tok, 'POST', `${EU}/bundles?uploadType=media`, {
    body: await readFile(aab), type: 'application/octet-stream',
  })
  console.log(`  AAB yuklendi: versionCode ${up.versionCode}`)
  await call(tok, 'PUT', `${E}/tracks/${track}`, {
    json: {
      track,
      // Hic yayinlanmamis uygulamada Play yalnizca "draft" surum kabul ediyor
      // ("Only releases with status draft may be created on draft app").
      // Ilk cikista `--taslak-surum` verilip surum Console'dan incelemeye
      // gonderiliyor; sonraki guncellemelerde bayrak gerekmiyor.
      releases: [{
        versionCodes: [String(up.versionCode)],
        status: relStatus,
        // "Yenilikler" metni. Bos birakmak yeni ozelligi gorunmez kilardi;
        // dil basina 500 karakter siniri var.
        ...(notes ? { releaseNotes: Object.entries(notes).map(([language, text]) => ({ language, text })) } : {}),
      }],
    },
  })
  console.log(`  "${track}" kanalina alindi\n`)
}

// `PUT /details` TUM kaynagi degistiriyor: gondermedigin alan SILINIYOR.
//
// Fusera'da bu, listelemenin `contactWebsite` alanini ucurdu ve AdMob'un
// app-ads.txt eslesmesini bir gun boyunca bozdu -- reklamlar "sinirli
// reklam sunumu"nda takildi ve sebebi gorunur degildi. Once GET ile
// mevcut hali alip uzerine yaziyoruz.
if (privacyUrl || opt('site') || opt('email')) {
  const mevcut = await call(tok, 'GET', `${E}/details`)
  const yeni = {
    ...mevcut,
    defaultLanguage: mevcut.defaultLanguage || 'en-US',
    ...(opt('email') ? { contactEmail: opt('email') } : {}),
    ...(opt('site') ? { contactWebsite: opt('site') } : {}),
    ...(privacyUrl ? { privacyPolicyUrl: privacyUrl } : {}),
  }
  await call(tok, 'PUT', `${E}/details`, { json: yeni })
  console.log(`  listeleme bilgileri guncellendi${privacyUrl ? `: ${privacyUrl}` : ''}\n`)
}

if (flag('no-commit')) {
  console.log('  --no-commit verildi: hicbir sey uygulanmadi (duzenleme kendiliginden dusecek).\n')
  process.exit(0)
}

await call(tok, 'POST', `${E}:commit`)
console.log('  UYGULANDI.\n')
console.log('  Not: bu islem uygulamayi YAYINLAMAZ. Metin ve gorseller Play Console')
console.log(`  "Yayinlama ozeti" sayfasinda, surum ise "${track}" kanalinda bekliyor.\n`)
