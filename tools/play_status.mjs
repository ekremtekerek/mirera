#!/usr/bin/env node
//
// Play'deki kanal durumunu OKUR. Hicbir sey degistirmez.
//
//   node tools/play_status.mjs --key D:/Tools/play-api/foldera-sa.json
//
// NEDEN BU VAR: yukleme betigi "uygulandi" yaziyor ama bu, surumun gercekten
// uretim kanalinda ve hangi durumda oldugunu SOYLEMIYOR. Bir kez daha
// "onaylandi" diye rapor vermeye cok yaklastim: bir izleyici betigi
// `grep -q "1.1.4"` ile magaza sayfasini tarayip noktalari joker gibi
// esletmis ve alakasiz bir JS parcasini surum sanmisti. O yuzden durum artik
// KAYNAGINDAN, Play API'sinden okunuyor.
//
// Salt okunur oldugu icin uretim freni yok: hicbir seyi yayina almiyor.
//
import { createSign } from 'node:crypto'
import { readFile } from 'node:fs/promises'

const PKG = 'com.mirera.game'
const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3'

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i > -1 && process.argv[i + 1] ? process.argv[i + 1] : d
}
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
  return body.access_token
}

const call = async (tok, method, url, body) => {
  const res = await fetch(url, {
    method,
    headers: { authorization: `Bearer ${tok}`, 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  })
  const text = await res.text()
  if (!res.ok) die(`${method} ${url.replace(API, '')}\n  ${text.slice(0, 400)}`)
  return text ? JSON.parse(text) : {}
}

const keyPath = arg('key')
if (!keyPath) die('--key <servis-hesabi.json> gerekli')

const tok = await token(keyPath)

// Durumu okumak icin de bir "edit" acmak gerekiyor; acip birakiyoruz --
// commit edilmeyen bir edit hicbir sey degistirmiyor ve kendiliginden dusuyor.
const edit = await call(tok, 'POST', `${API}/applications/${PKG}/edits`)

console.log(`\nMIRERA -> Play durumu  (${PKG})\n`)
for (const kanal of ['production', 'beta', 'alpha', 'internal']) {
  let t
  try {
    t = await call(tok, 'GET', `${API}/applications/${PKG}/edits/${edit.id}/tracks/${kanal}`)
  } catch { continue }
  const rel = t.releases ?? []
  if (rel.length === 0) { console.log(`  ${kanal.padEnd(11)} —`); continue }
  for (const r of rel) {
    const kod = (r.versionCodes ?? []).join(', ') || '—'
    const pay = r.userFraction != null ? `  yayilim %${Math.round(r.userFraction * 100)}` : ''
    console.log(`  ${kanal.padEnd(11)} surum ${kod}  durum: ${r.status}${pay}`
      + (r.name ? `  ("${r.name}")` : ''))
  }
}

// Uygulamanin kendi yayin durumu: incelemede mi, yayinda mi.
const app = await call(tok, 'GET', `${API}/applications/${PKG}/edits/${edit.id}/details`)
console.log(`\n  varsayilan dil: ${app.defaultLanguage}   iletisim: ${app.contactEmail ?? '—'}`)
// Site alani AdMob icin KRITIK: app-ads.txt dogrulamasi listelemedeki bu
// adrese bakiyor. Fusera'da bos kaldi ve reklamlar bir gun boyunca
// "sinirli reklam sunumu"nda takildi; alan hicbir yerde gorunmedigi icin
// sebebi aramak uzun surdu. Artik her durum sorgusunda yaziliyor.
console.log(`  site: ${app.contactWebsite ?? '— (AdMob app-ads.txt dogrulamasi BUNA bakiyor)'}`)
console.log('\n  Not: "completed" = surum kanalda ve tam yayilimda; Google incelemesi')
console.log('  bittikten sonra magazada gorunur. Inceleme durumu API\'de yer almiyor,')
console.log('  Play Console "Yayinlama ozeti" sayfasindan bakiliyor.\n')
