# Etki Kartı Denge Raporu

Tarih: 20 Temmuz 2026<br>
Oyun sürümü: 0.7 RC<br>
RC kapısı: 78 tamamlanmış üretim AI maçı, kart başına 6 odak maç

## Sonuç

On üç Etki Kartının tamamı üretim resolver'ları ve Orta AI planlayıcısıyla ölçüldü. Geçersiz AI hamlesi, yarım kalan maç, zorunlu seçim sapması veya frame sınırı aşımı görülmedi. Her kart en az beş maçta, on ikisi altı maçın tamamında tetiklendi. %95 Wilson aralıkları hiçbir kart için “açıkça baskın” (alt sınır > %60) ya da “açıkça zayıf” (üst sınır < %40) eşiğini geçmedi; RC için sayısal kart değişikliği yapılmadı.

Kanat Manevrası ham %16,7 ile alt; Muhafız Nöbeti ve Saha Hekimleri %83,3 ile üst tarafta görünür. Altı maçlık aralıklar hâlâ geniş olduğundan bu sonuçlar değişiklik emri değil, sonraki geniş koşu için izleme sinyalidir.

## Yöntem

- Test: `tests/effect_card_balance_suite.gd`
- Seed çizelgesi: `917000 + sample * 7919`
- Zorluk: iki oyuncuda Orta
- Her kart iki koltukta ve ilk/ikinci oyuncu olarak dengeli biçimde koşuldu: 3 ilk oyuncu, 3 ikinci oyuncu maçı.
- Rakip Etki Kartları diğer kartlar üzerinde deterministik döndürüldü; aynı kartın iki tarafa zorlandığı mirror maçı kullanılmadı.
- Sahne, `GameManager`, `BattlefieldUI`, `AIController`, gerçek deste çekişi ve merkezi resolver'lar kullanıldı. Test için paralel bir savaş modeli oluşturulmadı.
- Denge sinyali ham kazanma oranıyla değil %95 Wilson aralığıyla değerlendirildi.
- Deterministik sonuç imzası: `effect-balance-090538a2`

## Kart sonuçları

| Etki Kartı | G/K | Kazanma | %95 Wilson | Tetiklenen maç | Ort. tetik | Ort. raund |
|---|---:|---:|---:|---:|---:|---:|
| Dövme Ocağı | 4/2 | %66,7 | %30,0–%90,3 | %100 | 2,17 | 14,00 |
| Gizli Cephanelik | 3/3 | %50,0 | %18,8–%81,2 | %83,3 | 2,83 | 14,33 |
| İkmal Hattı | 4/2 | %66,7 | %30,0–%90,3 | %100 | 1,67 | 16,17 |
| İlkel Uyum | 4/2 | %66,7 | %30,0–%90,3 | %100 | 8,33 | 12,33 |
| Kanat Manevrası | 1/5 | %16,7 | %3,0–%56,4 | %100 | 7,00 | 15,00 |
| Koruyucu Yemin | 4/2 | %66,7 | %30,0–%90,3 | %100 | 12,67 | 14,17 |
| Kuşatma Planı | 4/2 | %66,7 | %30,0–%90,3 | %100 | 4,83 | 13,50 |
| Muhafız Nöbeti | 5/1 | %83,3 | %43,6–%97,0 | %100 | 9,17 | 13,17 |
| Öncü Doktrini | 4/2 | %66,7 | %30,0–%90,3 | %100 | 8,00 | 11,50 |
| Saha Hekimleri | 5/1 | %83,3 | %43,6–%97,0 | %100 | 10,00 | 14,33 |
| Son Direniş | 2/4 | %33,3 | %9,7–%70,0 | %100 | 4,33 | 12,00 |
| Usta Zanaatkârlar | 4/2 | %66,7 | %30,0–%90,3 | %100 | 3,33 | 13,67 |
| Yapı Ustaları | 4/2 | %66,7 | %30,0–%90,3 | %100 | 3,33 | 15,00 |

`İkmal Hattı` için “tetik” yalnızca gerçek kart çekişidir. İlk pozitif Enerji harcamasının sonuçsuz kontrol edilmesi ayrı snapshot ledger'ında tutulur ve bu tabloya tetik olarak yazılmaz.

## Denge kararı

1. Mevcut değerler RC için korunuyor; Wilson eşiğini geçen kart yok.
2. Kanat Manevrası, Muhafız Nöbeti ve Saha Hekimleri canlı telemetride izlenecek.
3. İkinci karar koşusu için en az `TDM_EFFECT_BALANCE_MATCHES_PER_CARD=12`, tercih olarak 40 odak maç/kart kullanılacak.
4. Bir sonraki değişiklik yalnızca güven aralığı eşik geçerse veya gerçek oyuncu telemetrisi aynı yönü doğrularsa yapılacak; nadirlik güç çarpanı olarak kullanılmayacak.

Yeniden üretim:

```powershell
$env:TDM_EFFECT_BALANCE_MATCHES_PER_CARD = '12'
& $env:DARWINE_GODOT_TEST --headless --path . --script res://tests/effect_card_balance_suite.gd
```
