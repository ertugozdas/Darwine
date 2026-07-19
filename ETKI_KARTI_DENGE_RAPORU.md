# Etki Kartı Denge Raporu

Tarih: 16 Temmuz 2026  
Oyun sürümü: 0.6 Alpha  
Koşu: 120 tamamlanmış üretim AI maçı, kart başına 12 odak maç

## Sonuç

On Etki Kartının tamamı üretim resolver'ları ve Orta AI planlayıcısıyla en az bir kez tetiklendi. Geçersiz AI hamlesi, yarım kalan maç, zorunlu seçim sapması veya frame sınırı aşımı görülmedi. %95 Wilson aralıkları hiçbir kart için “açıkça baskın” (alt sınır > %60) ya da “açıkça zayıf” (üst sınır < %40) eşiğini geçmedi. Bu nedenle kurallarda veya sayısal değerlerde değişiklik yapılmadı.

Kanat Manevrası ham %25 kazanma oranıyla izleme adayıdır; ancak %95 aralığı %8,9–%53,2 olduğu için 12 maçlık örneklem onu güvenilir biçimde etkisiz ilan etmeye yetmez. Koruyucu Yemin ham %66,7 ile üstte görünür, fakat alt güven sınırı yalnızca %39,1'dir. İki kart da sonraki geniş telemetri koşusunda yeniden ölçülmelidir.

## Yöntem

- Test: `tests/effect_card_balance_suite.gd`
- Seed çizelgesi: `917000 + sample * 7919`
- Zorluk: iki oyuncuda Orta
- Her kart iki koltukta ve ilk/ikinci oyuncu olarak dengeli biçimde koşuldu: 6 ilk oyuncu, 6 ikinci oyuncu maçı.
- Rakip Etki Kartları dokuz kart üzerinde deterministik döndürüldü; aynı kartın iki tarafa zorlandığı mirror maçı kullanılmadı.
- Sahne, `GameManager`, `BattlefieldUI`, `AIController`, gerçek deste çekişi ve merkezi resolver'lar kullanıldı. Test için paralel bir savaş modeli oluşturulmadı.
- Denge sinyali ham kazanma oranıyla değil %95 Wilson aralığıyla değerlendirildi.
- Deterministik sonuç imzası: `effect-balance-d94049e8`

## Kart sonuçları

| Etki Kartı | G/K | Kazanma | %95 Wilson | Tetiklenen maç | Ort. tetik | Ort. raund |
|---|---:|---:|---:|---:|---:|---:|
| Dövme Ocağı | 6/6 | %50,0 | %25,4–%74,6 | %100 | 2,83 | 14,50 |
| Gizli Cephanelik | 5/7 | %41,7 | %19,3–%68,0 | %100 | 4,00 | 15,00 |
| İkmal Hattı | 7/5 | %58,3 | %32,0–%80,7 | %75,0 | 1,08 | 14,75 |
| Kanat Manevrası | 3/9 | %25,0 | %8,9–%53,2 | %100 | 5,25 | 14,33 |
| Koruyucu Yemin | 8/4 | %66,7 | %39,1–%86,2 | %100 | 14,33 | 15,92 |
| Kuşatma Planı | 5/7 | %41,7 | %19,3–%68,0 | %91,7 | 8,33 | 16,67 |
| Öncü Doktrini | 5/7 | %41,7 | %19,3–%68,0 | %100 | 6,33 | 13,83 |
| Saha Hekimleri | 6/6 | %50,0 | %25,4–%74,6 | %100 | 12,92 | 16,83 |
| Son Direniş | 5/7 | %41,7 | %19,3–%68,0 | %75,0 | 3,83 | 15,17 |
| Yapı Ustaları | 6/6 | %50,0 | %25,4–%74,6 | %100 | 4,33 | 16,58 |

`İkmal Hattı` için “tetik” yalnızca gerçek kart çekişidir. İlk pozitif Enerji harcamasının sonuçsuz kontrol edilmesi ayrı snapshot ledger'ında tutulur ve bu tabloya tetik olarak yazılmaz. Denge koşusu hazırlanırken bu ayrım düzeltilmiş, final 120 maç temiz sayaçlarla yeniden çalıştırılmıştır.

## Denge kararı

1. Mevcut +2/+1, maliyet indirimi ve hasar azaltma değerleri korunuyor.
2. Kanat Manevrası ve Koruyucu Yemin için canlı telemetri veya en az 40 odak maç/kart içeren ikinci koşu öneriliyor.
3. Koşullu kartlarda düşük tetiklenme tek başına zayıflık sayılmıyor: İkmal Hattı Enerjinin tam sıfırlanmasını, Son Direniş ise Merkez hasarını gerektiriyor.
4. Bir sonraki değişiklik yalnızca güven aralığı eşik geçerse veya gerçek oyuncu telemetrisi aynı yönü doğrularsa yapılmalı; nadirlik güç çarpanı olarak kullanılmamalı.

Yeniden üretim:

```bash
TDM_EFFECT_BALANCE_MATCHES_PER_CARD=12 \
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
--script res://tests/effect_card_balance_suite.gd
```
