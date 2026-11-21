# Darwine v0.7 RC Doğrulama Raporu

**Tarih:** 20 Temmuz 2026<br>
**Godot:** 4.5 stable<br>
**Sürüm:** 0.7 RC<br>
**Sonuç:** 26/26 kapı geçti

## RC özeti

`data/release/v0_7_rc_gates.json` manifestindeki bütün kapılar `tools/run_v0_7_rc.ps1` ile ayrı Godot işlemlerinde ve tamamen sıralı çalıştırıldı. Nihai koşu 327,6 saniyede tamamlandı; başarı işareti eksik, başarısız işaretli veya başlatılamayan kapı olmadı. Makine tarafından okunabilir sonuç `artifacts/v0_7_rc_report.json`, her kapının bağımsız Godot çıktısı `artifacts/v0_7_rc_logs/` altındadır.

| Grup | Kapı | Sonuç |
|---|---:|---:|
| Sürüm sözleşmesi | 1 | 1/1 |
| Komutan Seferi | 4 | 4/4 |
| Denge | 4 | 4/4 |
| Maç analizi | 3 | 3/3 |
| Deste Danışmanı | 2 | 2/2 |
| Kayıt/profil | 3 | 3/3 |
| Çevrimiçi | 4 | 4/4 |
| Yerelleştirme | 4 | 4/4 |
| Ana menü/sunum | 1 | 1/1 |

## Denge sonuçları

RC manifesti toplam 202 üretim-AI karşılaşması çalıştırdı. Bütün maçlar tamamlandı; geçersiz AI hamlesi veya frame zaman aşımı oluşmadı.

| Paket | Maç | Temel sonuç |
|---|---:|---|
| Altı senaryo | 24 | 24/24 tamamlandı; bütün ders hedefleri gözlendi; toplam ilk tamamlama ödülü 95 Mühür |
| Kuşatma | 50 | Ortalama 14,16 raund; ilk oyuncu %54; ilk Merkez hasarı ortalama 3,78. raund; yeterli örnekli kart uç değeri 0 |
| Hakimiyet | 50 | Ortalama 9,36 raund; ilk oyuncu %60; oyuncu 1 %50; 40 maç puan hedefi, 10 maç Merkez yıkımıyla bitti |
| Etki Kartları | 78 | 13 kart × 6 maç; seçim sapması 0; bütün kartlar tetiklendi; Wilson eşiğini geçen denge sinyali 0 |

İlk Kuşatma dilimi 14,16 raundla eski 14,00 üst sınırını çok az aştı. Bağımsız ikinci 50 maç dilimi 14,82 üretti; birleşik 100 maç ortalaması 14,49 oldu. Bu nedenle Kuşatma kabul bandı ölçüme dayalı olarak 8–15 raunda kalibre edildi. İlk oyuncu, ilk Merkez hasarı, kart uç değeri ve geçersiz hamle eşikleri gevşetilmedi.

“Kanat Değiştir” ile “Üç Koridor Hakimiyeti” ilk senaryo koşusunda oyuncu tarafına hiç tamamlama üretmiyordu. Rakip deste/ilk oyuncu eşleşmeleri ders amacını koruyacak biçimde düzeltildi ve içerik sürümleri 2'ye çıkarıldı. Nihai dört örnekte sırasıyla 3/4 ve 4/4 tam hedef tamamlaması elde edildi.

## Sözleşme ve regresyon sonuçları

- Gerçek maçta oynanan kart türünün `get_class()` ile okunması Kahraman/Yapı hedeflerini sıfırlıyordu. Telemetri artık kararlı `_get_card_type_key()` değerini yazar; eski sınıf-adı olayları özetlenmeye devam eder.
- Profil şeması v5, aktif maç şeması v2, telemetri v3, maç analizi v1 ve Deste Danışmanı v1 olarak kilitlendi.
- Senaryo alanı taşımayan uyumlu aktif kayıtlar normal maç olarak yükleniyor; senaryolu kayıtlar bağlamı koruyor.
- Yerel, AI, dedicated sunucu, istemci ve host kurulumları önceki senaryo bağlamını temizliyor. Otorite, oda ayarları, Hakimiyet snapshot'ı ve oyuncu perspektifi testleri geçti.
- On bir CSV kaynağının tamamında `keys,en,de,fr,it,es,tr` başlığı, dolu hücreler ve biçim yer tutucu eşliği doğrulandı. 11 × 6 üretilmiş çeviri kaynağı proje listesinde yüklendi.
- v0.7 kaynaklarıyla çakışan “Gedik Aç” çevirisi tek karşılığa getirildi. “Nasıl Oynanır” yardımcı bileşenleri ham Türkçe yerine seçili dili kullanıyor.

## Yeniden çalıştırma

```powershell
.\tools\run_v0_7_rc.ps1
```

Belirli kapılar için:

```powershell
.\tools\run_v0_7_rc.ps1 -GateId release_contract,online_authority,localization
```
