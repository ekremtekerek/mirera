#!/usr/bin/env node
//
// Yuklu bir surumu baska bir kanala YUKSELTIR (yeniden yukleme yapmadan).
//
//   node tools/play_promote.mjs --key <sa.json> --surum 1 --kanal production
//
// NEDEN BU VAR: `play_publish.mjs --aab` her seferinde YENI bir paket
// yukluyor ve Play ayni surum kodunu ikinci kez kabul etmiyor
// ("Version code 1 has already been used"). Oysa test kanalindaki paketle
// uretime cikan paket AYNI OLMALI -- yeniden derlemek hem gereksiz hem de
// "test ettigin sey ile yayinladigin sey ayni mi" sorusunu aciyor.
//
// Bu betik yalnizca kanal atamasini degistiriyor: ayni versionCode, ayni
// imza, ayni bayt dizisi.
//
import { createSign } from 'node:crypto'
import { readFile } from 'node:fs/promises'

const PKG = 'com.mirera.game'
const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i > -1 && process.argv[i + 1] ? process.argv[i + 1] : d
}
const flag = (n) => process.argv.includes(`--${n}`)
const die = (m) => { console.error(`\n  HATA: ${m}\n`); process.exit(1) }
const b64url = (b) => Buffer.from(b).toString('base64url')

async function token(keyPath) {
  const sa = JSON.parse(await readFile(keyPath, 'utf8'))
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
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${head}.${claim}.${b64url(signer.sign(sa.private_key))}`,
    }),
  })
  const body = await res.json()
  if (!res.ok) die(`token alinamadi: ${JSON.stringify(body)}`)
  console.log(`  kimlik: ${sa.client_email}`)
  return body.access_token
}

const call = async (tok, method, url, json) => {
  const res = await fetch(url, {
    method,
    headers: { authorization: `Bearer ${tok}`, 'content-type': 'application/json' },
    body: json ? JSON.stringify(json) : undefined,
  })
  const text = await res.text()
  if (!res.ok) die(`${method} ${url.replace(API, '')}\n  ${res.status} ${text.slice(0, 400)}`)
  return text ? JSON.parse(text) : {}
}

const keyPath = arg('key') || die('--key gerekli')
const surum = parseInt(arg('surum') || '0', 10) || die('--surum <versionCode> gerekli')
const kanal = arg('kanal', 'internal')

// ULKE LISTESI BU API ILE AYARLANAMIYOR.
//
// Kanalda hic ulke secili degilse yukseltme reddediliyor:
//   "Release in track targeting no countries"
// Ama release icine `countryTargeting` koymak da calismiyor:
//   "Country targeting is only supported for staged releases"
//
// Yani tam yayinda ulke secimi bir kez Play Console'dan yapilmali;
// sonrasinda bu betik sorunsuz calisiyor.

// Uretim freni: play_publish.mjs'deki ile ayni gerekce.
if (kanal === 'production' && !flag('uretime-cik')) {
  die('uretim kanali icin `--uretime-cik` bayragi gerekli.')
}

const tok = await token(keyPath)
const edit = await call(tok, 'POST', `${API}/applications/${PKG}/edits`)
const E = `${API}/applications/${PKG}/edits/${edit.id}`

//
// HIC YAYINLANMAMIS uygulamada surum "draft" olmak ZORUNDA.
//
// Play, hic yayina cikmamis bir uygulamayi "taslak uygulama" sayiyor ve
// uzerine tam yayilimli bir surum kabul etmiyor:
//   "Only releases with status draft may be created on draft app."
//
// Taslak surum kanalda birikiyor, sonra Play Console'daki "Yayinlama
// ozeti" sayfasindan incelemeye gonderiliyor. Uygulama bir kez yayina
// ciktiktan sonra 'completed' calisiyor ve --taslak gerekmiyor.
const durum = flag('taslak') ? 'draft' : 'completed'

//
// Surum notlari: dil basina 500 karakter siniri var. Ilk surumde bos
// birakmak Play Console'da "0/13 dil icin surum notlari saglandi" diye
// duruyor ve magazada "Yenilikler" bolumu bos cikiyor.
const notlarYolu = arg('notlar')
const notlar = notlarYolu
  ? JSON.parse(await (await import('node:fs/promises')).readFile(notlarYolu, 'utf8'))
  : null

await call(tok, 'PUT', `${E}/tracks/${kanal}`, {
  track: kanal,
  releases: [{
    versionCodes: [String(surum)],
    status: durum,
    ...(notlar
      ? { releaseNotes: Object.entries(notlar).map(([language, text]) => ({ language, text })) }
      : {}),
  }],
})
console.log(`  surum ${surum} -> "${kanal}" kanalina yukseltildi (${durum})`)

await call(tok, 'POST', `${E}:commit`)
console.log('\n  UYGULANDI.\n')
