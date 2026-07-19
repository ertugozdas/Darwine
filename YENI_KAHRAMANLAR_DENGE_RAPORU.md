# 10 Yeni Kahraman Kartı Entegrasyon ve Denge Raporu

**Tarih:** 17 Temmuz 2026  
**Godot:** 4.7 stable  
**Son havuz:** 33 Kahraman, 77 oynanabilir kart

## Kart seti

| Kart | Nadirlik | Enerji | Güç / Zırh / Can | Özgün mekanik |
|---|---|---:|---:|---|
| Çan Muhafızı | Nadir | 3 | 2 / 2 / 6 | **Siper:** Sahibinin Tur Başlangıcından sonraki ilk normal saldırıdan 2 hasar azaltır. |
| Kül Sancaktarı | Destansı | 4 | 3 / 1 / 6 | **Savaş Sancağı:** Aynı koridordaki dost Kahramanların, kendisi dahil, normal saldırılarına +1 hasar verir; birikmez. |
| Fırtına Nakkaşı | Destansı | 3 | 3 / 0 / 5 | **Akım İzi:** Başka koridora hareket edince varış koridorundaki ilk düşmana 1 hasar verir. |
| Yankı Celladı | Nadir | 3 | 3 / 1 / 5 | **Yarma:** Normal saldırıdan sonra aynı koridordaki sıradaki düşmana 1 hasar verir. |
| Zaman Hırsızı | Destansı | 3 | 4 / 0 / 4 | **Çalınan An:** Turdaki ilk düşman Kahraman yok edişinde 2 Can yeniler ve Hazır olur. |
| Boşluk Gezgini | Nadir | 3 | 3 / 1 / 4 | **Faz Yürüyüşü:** Hazırlıkta boş herhangi bir dost Ön veya Arka Hat yuvasına tek hamlede gider. |
| Güneşsiz Kraliçe | Efsanevi | 5 | 4 / 2 / 7 | **Tutulma:** Aynı koridordaki düşman normal saldırılarını 1 azaltır; birikmez. |
| Ruh Fenercisi | Destansı | 3 | 2 / 1 / 6 | **Ruh Bağı:** Raundda bir kez aynı koridorda başka bir dost Kahraman yok edilince 1 Can yeniler ve 1 Korumalı kazanır. |
| Kırıktaç Yeminlisi | Nadir | 2 | 3 / 0 / 5 | **Son Nefes:** Yarı Can veya altındayken normal saldırıları +2 hasar verir. |
| Demirkök Şamanı | Efsanevi | 5 | 3 / 3 / 8 | **Kök Salma:** Hareket etmediği Tur Sonunda 1 Can; Canı tam ise bunun yerine 1 Zırh yeniler. |

Yeni set dağılımı 4 Nadir, 4 Destansı ve 2 Efsanevi karttır. Toplam Kahraman dağılımı 16 Nadir, 12 Destansı ve 5 Efsanevi olmuştur.

## Entegrasyon kapsamı

- Kart verileri `data/cards/heroes.json` içine eklendi.
- On mekanik `effect_resolver.gd`, `combat_resolver.gd`, `movement_resolver.gd` ve `progression_resolver.gd` üzerinden gerçek oyun akışına bağlandı.
- AI; oynama, koridor, hareket, saldırı, bitirici hasar ve yeni pasiflerin değerini hesaba katacak şekilde güncellendi.
- Tur/raund kullanım durumu `trait_runtime` ile kart üzerinde tutuluyor; aktif maç kaydı ve ağ snapshot'ı bu alanı tam tur olarak saklayıp geri yüklüyor.
- On anahtar kelime ortak sözlüğe eklendi.
- Kart adları, açıklamaları ve sözlük metinleri İngilizce, Almanca, Fransızca, İtalyanca, İspanyolca ve Türkçe olarak eklendi.
- Deste Atölyesi ve Tüm Kartlar modu 77 kartlık havuzla doğrulandı.

## Görsel üretim

**Mod:** yerleşik imagegen, yeni görsel üretimi (`generate`), `stylized-concept` yönü.

Ortak prompt omurgası:

> Original dark-fantasy trading-card hero portrait, cinematic painterly realism, strong readable silhouette and face, character-specific magical motif, dramatic atmospheric lighting, vertical composition with the subject readable in the upper card-art area, no text, no logo, no card frame, no watermark.

Karakter varyasyonları sırasıyla çan kalkanlı muhafız, kül sancağı taşıyan savaşçı, fırtına rünleri çizen nakkaş, yankılı hilal baltalı cellat, zaman kristalli hırsız, boşluk yarığı yolcusu, tutulma tahtındaki kraliçe, ruh fenerli rehber, kırık taç yeminlisi ve demir-kök şamanı olarak üretildi. Görseller mevcut kart sanat standardına göre 1086×1448 PNG biçimine normalize edilip `images/heroes/` altına kaydedildi.

## Denge sonuçları

### Kuşatma

| Ölçüm | Sonuç | Kabul |
|---|---:|---:|
| Tamamlanan maç | 50 / 50 | 50 / 50 |
| Geçersiz AI hamlesi | 0 | 0 |
| Ortalama raund | 13,78 | 8–14 |
| En kısa / uzun maç | 6 / 28 | Zaman aşımı yok |
| İlk oyuncu kazanma oranı | %44 | %44–56 |
| İlk Merkez hasarı | 3,12. raund | 3–7 |
| Farklı açılış kartı | 34 | En az 4 |
| Kullanım-kazanma uç değeri | 0 / 77 kart | 0 |

Yeni Kahramanların 50 maçlık kullanım-kazanma oranları `%41,7–55,6` bandında kaldı. Zaman Hırsızı 3 Enerjiye, Orta AI hazırlık bütçesi 6 hamleye ve ikinci oyuncunun tek kullanımlık açılış Merkez kalkanı ölçülen denge için 1 puana ayarlandı.

### Hakimiyet

| Ölçüm | Sonuç | Kabul |
|---|---:|---:|
| Tamamlanan maç | 50 / 50 | 50 / 50 |
| Geçersiz AI hamlesi | 0 | 0 |
| Ortalama raund | 9,0 | 4–14 |
| İlk oyuncu kazanma oranı | %48 | %40–60 |
| Oyuncu 1 kazanma oranı | %58 | %35–65 |
| İlk Hakimiyet puanı | 1,7. raund | 1–4 |
| Hakimiyet hedefiyle biten | 40 / 50 | En az 35 / 50 |

## Geçen doğrulama kapıları

- `NEW_HERO_CARDS_SMOKE_OK`
- `CARD_ART_AUDIT_OK`
- `CARD_TEMPLATE_AUDIT_OK`
- `PHASE_SIX_CONTENT_SMOKE_OK`
- `NEW_CARD_EXPANSION_SMOKE_OK`
- `LOCALIZATION_SMOKE_OK`
- `DECK_BUILDER_SMOKE_OK`
- `DOMINION_NETWORK_SMOKE_OK`
- `ACTIVE_MATCH_SAVE_SMOKE_OK`
- `PHASE_SEVEN_AI_SMOKE_OK`
- `DOMINION_RULES_SMOKE_OK`
- `DOMINION_AI_SMOKE_OK`
- `DOMINION_PERSISTENCE_SMOKE_OK`
- `PHASE_SEVEN_BALANCE_SUITE_OK` (Kuşatma ve Hakimiyet)
