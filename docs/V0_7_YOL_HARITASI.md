# Darwine v0.7 — Komutan Seferi ve Ustalık

**Sürüm hedefi:** Yeni oyuncuyu öğretilebilir senaryolarla oyuna almak, maç sonuçlarını açıklanabilir hâle getirmek ve mevcut kart havuzunda deste kurmayı kolaylaştırmak.

## Kapsam sınırı

v0.7 aşağıdaki dört zorunlu teslimden oluşur:

1. **Komutan Seferleri:** Yerleşim, Enerji, açık koridor, hareket, Etki Kartları ve Hakimiyet derslerini içeren altı sabit senaryo.
2. **Maç Sonu Analizi:** Kritik koridor, Enerji kullanımı, hareket ve saldırı metriklerini mevcut maç özetiyle birleştiren açıklanabilir sonuç ekranı.
3. **Deste Danışmanı:** Enerji eğrisi, kart türü dağılımı ve anahtar kelime uyumu üzerinden yargılayıcı olmayan öneriler.
4. **Denge ve sürüm kapıları:** Senaryo, kayıt, telemetri, çevrimiçi akış ve altı dil için geriye dönük doğrulama.

Haftalık Meydan Okuma ve 6–8 kartlık küçük karşı-oyun seti, yalnızca zorunlu teslimler tamamlandıktan sonra ele alınır. Üçüncü ana oyun modu, dereceli sıra, paket ekonomisi ve tepki zinciri v0.7 kapsamı dışındadır.

## Milestone planı

| Milestone | Tahmini süre | Çıkış ölçütü | Durum |
|---|---:|---|---|
| M0 — Temel | 3 gün | Senaryo kataloğu, MatchSetup bağlamı, telemetri şeması ve temel duman testi | Tamamlandı |
| M1 — Komutan Seferleri | 2 hafta | Altı senaryo seçilebilir, oynanabilir, kaydedilebilir ve tamamlanabilir | Tamamlandı |
| M2 — Maç Sonu Analizi | 1 hafta | Kuşatma/Hakimiyet için oyuncu perspektifli karar metrikleri | Tamamlandı |
| M3 — Deste Danışmanı | 1 hafta | Enerji eğrisi, rol dağılımı ve uygulanabilir öneriler | Tamamlandı |
| M4 — Denge ve RC | 1 hafta | Hedef testleri, altı dil, kayıt ve çevrimiçi regresyon kapıları geçer | Tamamlandı |

## M0 veri sözleşmesi

Senaryolar `data/scenarios/v0_7_scenarios.json` dosyasında tutulur. Her senaryo aşağıdaki bölümleri taşır:

- Değişmez kimlik, sıra, içerik sürümü ve ders türü
- Kuşatma veya Hakimiyet kurallar seti
- Oyuncu/rakip başlangıç desteleri, AI seviyesi, ilk oyuncu ve Etki Kartı seçimi
- Telemetri metrikleri üzerinden ölçülen bir veya daha fazla zorunlu hedef
- Önceki senaryo bağımlılığı
- Rekabet gücü vermeyen ödül

Aktif maç kayıtlarında yalnızca kararlı senaryo bağlamı saklanır. Katalog içeriğinin tamamı snapshot içine kopyalanmaz. Bu sayede eski kayıtların boyutu ve ağ akışları değişmeden kalır.

### M0 kabul kriterleri

- Katalog hatalı şema, yinelenen kimlik, geçersiz deste/AI alanı ve ileriye dönük açılma bağımlılığını reddeder.
- Normal yerel, AI ve çevrimiçi yapılandırmalar eski senaryo bağlamını temizler.
- Senaryo bağlamı aktif maç snapshot'ına yazılır ve yüklemede geri alınır.
- Telemetri olayları şema sürümü ve senaryo kimliği taşır.
- Oyuncu özeti Kahraman/Yapı/Büyü/Beceri kullanımı, saldırı, Merkez saldırısı, hareket, koridorlar arası hareket, Etki çözümü ve Çatışmaya geçerken harcanmamış Enerji metriklerini üretir.

## M1 teslim özeti

- Ana menüde profil ilerlemesine göre kilit açan altı senaryolu Komutan Seferi ekranı bulunur.
- Her senaryo katalogdaki deste, AI seviyesi, ilk oyuncu, tur süresi, otomatik saldırı ve Etki Kartı kurulumuyla başlar.
- Savaş alanındaki Sefer Hedefleri düğmesi canlı telemetri ilerlemesini ve taktik brifingi gösterir.
- Maç sonucu aynı `match_id` için yalnız bir kez işlenir; ilk tamamlamada katalogdan doğrulanan kozmetik Mühür ödülü verilir.
- Senaryo bağlamı aktif maç kaydında korunur; yeniden yüklemede hedef görünümü ve ilerleme sözleşmesi devam eder.
- Sefer yüzeyleri İngilizce, Almanca, Fransızca, İtalyanca, İspanyolca ve Türkçe çeviri kaynaklarına bağlıdır.

## M2 teslim özeti

- Telemetri şema v3; gerçek harcanan Enerji, Savaş fazı örnekleri ve koridor bazında yerleşim, saldırı, Merkez saldırısı, hareket, etki hasarı ve kart yıkımı üretir.
- Saf analiz motoru sonucu oyuncu perspektifinden okur; kritik koridoru kanıt gücüyle birlikte seçer ve zayıf veride nedensellik iddiasında bulunmaz.
- Kuşatma analizi Enerji disiplini, Merkez baskısı ve koridor hareketini; Hakimiyet analizi ise Merkez saldırısı yerine koridor kontrolü ve puan dönüşümünü açıklar.
- Oyun sonu modalı kritik koridor ile üç uygulanabilir karar kartını gösterir; aynı analiz profil geçmişi kaydında korunur.
- Analiz yüzeyi ve tüm dinamik açıklama şablonları İngilizce, Almanca, Fransızca, İtalyanca, İspanyolca ve Türkçe sağlanır.

## M3 teslim özeti

- Deste Danışmanı canlı kart kataloğundan Enerji eğrisi, kart türleri, altı ana rol ve mekanik paketlerini deterministik olarak çıkarır; kart adına bağlı özel kurallar kullanmaz.
- Eğri, kompozisyon ve anahtar kelime uyumu için sayısal puan vermeyen; güçlü yönü, gelişim alanını ve uygulanabilir bir sonraki değişikliği açıklayan üç öneri üretir.
- Atölye’de kart ekleme/çıkarma anında analiz yenilenir. Kompakt görünüm eğri, roller ve öncelikli öneriyi gösterir; üç içgörü isteğe bağlı genişletilir.
- Ağır eğri, eksik/fazla/geçersiz deste, saha varlığı, Beceri hedefleri ve Büyü Yankısı desteği ayrı sözleşmelerle ele alınır.
- Deste Danışmanı yüzeyi ve dinamik şablonları altı dilde sağlanır; 1280×720 yerleşimi ile mevcut kayıt, etkinleştirme ve maça taşıma akışı doğrulanır.

## M4 teslim özeti

- Sürüm aşaması `0.7 RC` olarak yükseltildi; 26 kapılık makine-okunabilir manifest ve kapıları ayrı Godot işlemlerinde sıralı çalıştıran PowerShell koşucusu eklendi.
- Altı senaryoda 24, Kuşatma'da 50, Hakimiyet'te 50 ve 13 Etki Kartında 78 olmak üzere toplam 202 üretim-AI maçı nihai RC koşusunda tamamlandı. Geçersiz hamle, yarım maç veya zaman aşımı görülmedi.
- “Kanat Değiştir” ve “Üç Koridor Hakimiyeti” eşleşmeleri ders hedefini koruyarak tamamlanabilir hâle getirildi. Kuşatma süre bandı iki bağımsız 50 maç diliminin 14,49 birleşik ortalamasına göre 8–15 raunda kalibre edildi.
- Gerçek kart kullanımında Kahraman/Yapı sayaçlarını sıfırlayan kart türü telemetri hatası kararlı kart türü anahtarıyla düzeltildi; aktif kayıt ve analiz regresyonları yeniden geçti.
- Profil v5, aktif maç v2, eski kayıtta senaryo alanının yokluğu ve çevrimiçi kurulumlarda senaryo bağlamı temizliği tek RC sözleşmesinde doğrulandı.
- On bir çeviri kaynağında altı dil, boş hücre, başlık, biçim yer tutucu, üretilmiş kaynak ve v0.7 anahtar çakışması denetlendi. Nasıl Oynanır kartlarının gerçek seçili dili kullanması sağlandı.
- Nihai sonuç 26/26'dır. Ayrıntılar `V0_7_RC_RAPORU.md`, makine raporu `artifacts/v0_7_rc_report.json` içindedir.

## Sürüm kapıları

- Yeni özellikler mevcut `GameManager` ve resolver akışını kullanır; paralel savaş modeli oluşturulmaz.
- Senaryo ilerlemesi kart, Enerji veya savaş gücü kazandırmaz.
- Mevcut kayıtlar senaryo alanı olmadan yüklenmeye devam eder.
- Bütün kullanıcı metinleri görünür oldukları milestone içinde İngilizce, Almanca, Fransızca, İtalyanca, İspanyolca ve Türkçe sağlanır.
- Her milestone kendi duman testiyle ve ilgili mevcut regresyon testleriyle kapanır.
