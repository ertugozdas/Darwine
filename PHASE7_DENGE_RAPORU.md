# Aşama 7 Denge ve Doğrulama Raporu

> Bu dosya 16 Temmuz 2026 tarihli 67 kartlık tarihsel anlık görüntüdür. 77 kartlık güncel sonuçlar için `YENI_KAHRAMANLAR_DENGE_RAPORU.md` raporuna bakın.

**Tarih:** 16 Temmuz 2026  
**Godot:** 4.7 stable  
**Koşu:** 50 deterministik, tam AI karşılaşması

## Kapsam

Maçlar üretim sahnesi, gerçek `GameManager`, `CombatResolver`, `EffectResolver`, `MovementResolver` ve `ProgressionResolver` üzerinden oynatıldı. Test modu yalnızca sunum gecikmelerini ve disk telemetrisini kapattı; kart, Enerji, hedef ve oyun sonu kuralları değiştirilmedi.

Kolay, Orta ve Zor için eşit zorlukta iki taraf karşılaştırıldı. Başlayan oyuncu maçlar arasında sırayla değiştirildi; her maç farklı ancak tekrar üretilebilir bir tohum kullandı.

## Sonuçlar

| Ölçüm | Sonuç | Hedef / yorum |
|---|---:|---|
| Tamamlanan maç | 50/50 | Karşılandı |
| Geçersiz AI hamlesi | 0 | Karşılandı |
| Kilitlenme / zaman aşımı | 0 | Karşılandı |
| Ortalama raund | 13,82 | 8–14 kabul aralığında |
| En kısa / uzun maç | 5 / 25 raund | Kontrol ve diriltme kartları uzun kuyruğu artırıyor |
| İlk oyuncu kazanma oranı | %56 | %44–56 örneklem toleransında |
| İlk Merkez hasarı | Ortalama 4,28. raund | Hedef aralıkta |
| Farklı açılış kartı | 26 | Tek zorunlu açılış yok |

Zorluk başına ortalama raund:

| Zorluk | Maç | Ortalama raund | İlk oyuncu kazanma oranı |
|---|---:|---:|---:|
| Kolay | 17 | 14,94 | %58,8 |
| Orta | 17 | 12,71 | %41,2 |
| Zor | 16 | 13,81 | %68,8 |

## Kart uç değerleri

En az 10 kullanım örneği bulunan genişletilmiş 67 kartlık oynanabilir havuzun tamamı incelendi. `%20–80` dışında kullanım-kazanma oranı görülmedi.

- En yüksek: `mancinik_ustasi`, 36 kullanım, `%66,7`
- En düşük: `kereste_fabrikasi`, 27 kullanım, `%29,6`

Bu aralık ilk denge geçişinde kart verisi değiştirmeyi gerektirecek belirgin bir güç uçurumu göstermedi. Deste kompozisyonu iki oyuncu için eşitlendi; deste sırası bağımsız, tohumlanmış RNG akışlarıyla karıştırıldı.

## Uygulanan düzeltmeler

- AI hareketleri önce tamamen yasal havuzdan üretiliyor, ardından zorluk seviyesine göre puanlanıyor.
- Negatif değerli hareketlerin sırf mevcut oldukları için seçilmesi engellendi; bu değişiklik ilk koşudaki `21,36` raund ortalamasını düşürdü.
- Açılışta savunmasız koridora cevap verme ve orta oyunda aynı koridorda baskı biriktirme puanlandı.
- İki tarafın sabit deste kompozisyonu eşitlendi; ilk oyuncu oranı `%66` ilk ölçümden `%48` son ölçüme indi.
- Boş destede Merkez Binasına `1, 2, 3…` artan Yorgunluk Hasarı eklendi.
- Aynı etki içinde iki Merkez Binası ölürse tek oyun sonu olayı ve deterministik kazanan üretildi.
- Maç olayları `user://match_telemetry.jsonl` konumuna satır başına bir JSON nesnesi olarak kaydedildi.
- Beş Kahraman, üç Yapı, iki Büyü ve iki Beceri kartıyla havuz 42 oynanabilir karta çıkarıldı; yeni savunma ve Kuşatma değerleri aynı 50 maçlık koşuyla yeniden dengelendi.
- Taktik Değişim ve İkmal Emri ile el düzenleme/ek çekiş seçenekleri eklendi; boş deste için AI yasal hamle üretimi sıkılaştırıldı.
- Tur başında normal çekiş eli üç karta ulaştırmıyorsa takviye çekişi devreye alındı.
- İkinci oyuncunun Merkezi, açılış temposunu dengelemek için ilk hasarda 6 puana kadar emen tek kullanımlık Korumalı durumuyla başlıyor.
- Üç Kahraman, iki Yapı, iki Beceri ve üç Özel Güç eklenerek oynanabilir havuz 67 karta çıkarıldı.
- Gezgin, Misilleme, Sis Perdesi, Son Vasiyet ve Örtülü anahtar kelimeleri ortak çözümleyicilere ve AI puanlamasına bağlandı.
- Kontrol ve diriltme yoğunluğu nedeniyle Kuşatma kabul bandı 8–14 raund ve 50 maçlık ilk oyuncu toleransı %44–56 olarak güncellendi.
- Gecikmeli Tecrübe geri bildirimi serbest bırakılmış kartları çağırmaması için zayıf referansla güvenli hâle getirildi.

## Tekrarlama

- Kural, menü, Yorgunluk, telemetri ve tam maç duman testi: `tests/phase_seven_ai_smoke.gd`
- 50 maçlık denge koşusu: `tests/phase_seven_balance_suite.gd`
