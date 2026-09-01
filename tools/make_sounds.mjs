#!/usr/bin/env node
//
// Ses dosyalarini SENTEZLER.  node tools/make_sounds.mjs
//
// Neden hazir dosya degil: sesler oyunun kendi malzemesinden uretilsin
// istedim -- palet gibi, tek yerden ayarlanabilsin. Ayrica lisans derdi
// yok ve dosyalar kucuk kaliyor.
//
// Cikti: 16-bit mono 44.1kHz WAV. Godot bunlari dogrudan okuyor.
//
import { writeFileSync, mkdirSync } from 'node:fs'

const SR = 44100

function wav(samples) {
  const n = samples.length
  const buf = Buffer.alloc(44 + n * 2)
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 2, 4); buf.write('WAVE', 8)
  buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20)
  buf.writeUInt16LE(1, 22); buf.writeUInt32LE(SR, 24)
  buf.writeUInt32LE(SR * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34)
  buf.write('data', 36); buf.writeUInt32LE(n * 2, 40)
  for (let i = 0; i < n; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]))
    buf.writeInt16LE(Math.round(v * 32000), 44 + i * 2)
  }
  return buf
}

const env = (t, dur, atk = 0.004) =>
  t < atk ? t / atk : Math.exp(-(t - atk) * (5.5 / dur))

//
// Patlama: alcak bir "tok" + ustune kisa bir ton. Saf sinus fazla "bip"
// duruyordu; gurultu atagi ona vurus hissi katiyor.
//
function pop(dur = 0.26, hz = 320) {
  const out = new Float32Array(Math.floor(SR * dur))
  for (let i = 0; i < out.length; i++) {
    const t = i / SR
    const e = env(t, dur)
    // Perde hafifce DUSUYOR: yukselen perde "soru", dusen "cevap" gibi
    // duyuluyor ve patlama bir cevaptir.
    const f = hz * (1.0 - 0.28 * Math.min(1, t / dur))
    const ton = Math.sin(2 * Math.PI * f * t)
    const vurus = (Math.random() * 2 - 1) * Math.exp(-t * 90)
    out[i] = (ton * 0.72 + vurus * 0.5) * e * 0.55
  }
  return out
}

//
// Kazanma: temel + besli + oktav, birlikte calan sicak bir akor.
//
function chime(dur = 1.5, hz = 523.25) {
  const out = new Float32Array(Math.floor(SR * dur))
  const kismi = [[1, 0.5], [1.5, 0.32], [2, 0.2]]
  for (let i = 0; i < out.length; i++) {
    const t = i / SR
    const e = t < 0.01 ? t / 0.01 : Math.exp(-(t - 0.01) * 2.6)
    let s = 0
    for (const [oran, g] of kismi) s += Math.sin(2 * Math.PI * hz * oran * t) * g
    out[i] = s * e * 0.4
  }
  return out
}

// Arayuz dokunusu: cok kisa, yumusak.
function tap(dur = 0.07, hz = 760) {
  const out = new Float32Array(Math.floor(SR * dur))
  for (let i = 0; i < out.length; i++) {
    const t = i / SR
    out[i] = Math.sin(2 * Math.PI * hz * t) * Math.exp(-t * 55) * 0.32
  }
  return out
}

mkdirSync('audio', { recursive: true })
const dosyalar = { 'pop.wav': pop(), 'chime.wav': chime(), 'tap.wav': tap() }
for (const [ad, s] of Object.entries(dosyalar)) {
  const b = wav(s)
  writeFileSync(`audio/${ad}`, b)
  console.log(`  ${ad.padEnd(11)} ${(b.length / 1024).toFixed(1)} KB  ${(s.length / SR).toFixed(2)} sn`)
}
console.log('\n  Bitti. Perde oyunda pitch_scale ile degistiriliyor.\n')
