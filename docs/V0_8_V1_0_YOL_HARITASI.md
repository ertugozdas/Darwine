# Darwine v0.8 → v1.0 — Tam Sürüme Giden Yol Haritası

**Belge durumu:** Plan önerisi<br>
**Başlangıç noktası:** v0.7 RC<br>
**Hedef sürümler:** v0.8, v0.9, v1.0<br>
**Ürün ilkesi:** Kart, Enerji, savaş gücü veya maç sonucu satın alma/ödül yoluyla güçlenmez. İlerleme ve rekabet ödülleri kozmetik, unvan, sancak ve profil görünümüyle sınırlıdır.

## 1. Amaç ve sürüm sıralaması

v0.7; yeni oyuncuyu altı senaryoyla öğreten, maç kararlarını açıklayan ve deste kurmayı kolaylaştıran ustalık sürümüdür. v1.0'a kadar ürünün üç açık ihtiyacı kalır:

1. **Tekrar oynama nedeni:** Öğrenilen sistemi düzenli olarak farklı taktik koşullarda kullanmak.
2. **Güvenilir rekabet:** Arkadaş/P2P maçlarından ayrı, sonucu istemcinin yazamadığı, adil bir dereceli akış.
3. **Yayınlanabilir bütünlük:** İçerik, Steam teslimi, erişilebilirlik, performans, kayıt güvenliği ve operasyonun tek bir ürün gibi kapanması.

Bu nedenle sürümler birbirinin yerine geçen değil, sırayla açılan katmanlardır:

| Sürüm | Çalışma adı | Ana soru | Çıkış sonucu |
|---|---|---|---|
| **v0.8** | **Sınır Hattı** | Oyuncu her hafta neden yeniden dönsün? | Haftalık Meydan Okuma, küçük karşı-oyun kart seti ve ölçülebilir tekrar oynama döngüsü |
| **v0.9** | **Sezon 0** | Rekabetçi maçın sonucu neden güvenilir olsun? | Dedicated/backend otoriteli dereceli beta, eşleştirme, rating ve sezon akışı |
| **v1.0** | **Darwine Tam Sürüm** | Oyun mağazada ve canlı kullanımda güvenle yayınlanabilir mi? | Kapsamı dondurulmuş, Steam'e hazır, operasyonel olarak izlenebilir tam sürüm |

### Kritik yol

```text
v0.7 Ustalık
    ↓
v0.8 Haftalık Meydan Okuma + Karşı Oyun
    ↓  (içerik dengesi ve düzenli oynama doğrulanır)
v0.9 Dedicated sonuç hattı + Dereceli Sezon 0
    ↓  (güvenilir rekabet ve operasyon doğrulanır)
v1.0 İçerik donması + Steam yayın hazırlığı + Launch RC
```

## 2. Planın değişmeyen kuralları

Bu yol haritasında yeni özellikler aşağıdaki ürün ve teknik kurallara uyar:

- **Tek savaş modeli:** Kart kuralları, `GameManager`, mevcut resolver'lar ve `MatchSetup` üzerinden çalışır. Test, meydan okuma veya ranked için paralel bir savaş simülasyonu yazılmaz.
- **Yetki ayrımı:** Yerel profil ve Steam Cloud; kayıt/ayar/kozmetik kolaylığı içindir. Dereceli sonuç, rating, sezon ödülü ve ceza yalnızca doğrulanan dedicated/backend yolundan yazılır.
- **Eşit rekabet:** Kart havuzu, deste sınırları, tur süresi ve kurallar maç başlamadan kilitlenir. İstemci bir sonucu, snapshot'ı, rating'i veya ödülü tek başına değiştiremez.
- **Geriye uyumluluk:** Yeni profil ve aktif-maç alanları sürümlenmiş olur; eski kayıtları okuyan migration testi aynı sürümde eklenir.
- **Yerelleştirme bir teslim maddesidir:** Yeni görünür metinler İngilizce, Almanca, Fransızca, İtalyanca, İspanyolca ve Türkçe sağlanmadan milestone kapanmaz.
- **Kozmetik dışı ödül yok:** Meydan okuma ve sezon ödülleri kart, seviye, Enerji, istatistik veya maç avantajı yaratmaz.
- **Veri önce, ekran sonra:** Katalog, sonuç ve migration sözleşmesi yazılmadan UI üretimi başlamaz.
- **Ölçmeden denge değişikliği yok:** Kart veya senaryo değeri, yalnızca yeterli deterministik test örneklemi veya canlı/beta verisiyle değiştirilir.

## 3. Mevcut temel ve açıklar

v0.7 sonunda aşağıdaki temel hazır kabul edilir:

- Altı senaryolu Komutan Seferi, seçilebilir kurallar, hedefler, profil ilerlemesi ve aktif-maç bağlamı.
- Kuşatma ve Hakimiyet için telemetri, maç sonu analizi ve Deste Danışmanı.
- Yerel/AI, Steam P2P ve dedicated sunucuda otoriter maç akışı; reconnect, rövanş ve snapshot kurtarması.
- Profil, görevler, başarımlar, kozmetikler, kayıt yedekleri ve Steam Cloud eşitlemesi.
- v0.7 için çalışan RC manifesti, sıralı test koşucusu ve altı dil denetimi.

Ancak aşağıdakiler henüz ürün olarak tamamlanmış değildir:

- Haftalık görevler vardır; fakat **tekil, kuralları sabit, ölçülebilir bir Haftalık Meydan Okuma ürünü** yoktur.
- Profilde rekabetçi alan için yer vardır; fakat **rating, eşleştirme, sonuç imzalama ve sezon ödül otoritesi** yoktur.
- Dedicated sunucu maç kurallarını doğrular; fakat **hesap kimliği, kuyruk, kalıcı maç sonucu deposu ve operasyon hizmeti** yoktur.
- Steam Cloud güvenli hesap eşitlemesidir; **anti-cheat veya trusted competitive backend değildir**.
- Mevcut kart seti dengelidir; fakat v0.7 sonrasında önerilen küçük karşı-oyun genişlemesi henüz ürüne dönüşmemiştir.

## 4. Ortak veri ve yayın sözleşmeleri

Sürüm bazlı detaylar aşağıdadır; bu bölüm tüm sürümlerin uygulama standardıdır.

### 4.1 Kimlikler ve sürümleme

- Her içerik kaydında değişmez `id`, görünür `content_version`, hedef `release_version` ve gerektiğinde `ruleset_version` bulunur.
- Her tamamlanan meydan okuma veya rekabetçi maç; benzersiz `match_id`, kuralların sürümü, seed, oyuncu/deck kimlikleri ve doğrulama sonucuyla izlenir.
- Bir maçın sonucu aynı `match_id` için idempotent olmalıdır: ağ tekrarı veya yeniden gönderim ikinci rating/ödül kaydı oluşturmaz.
- Eski aktif maçlar yeni bağlamı taşımıyorsa normal maça veya güvenli biçimde "bu sürümde devam edemez" durumuna düşer; sessiz veri kaybı olmaz.

### 4.2 Sürüm geçişleri

| Geçiş | Planlanan değişim | Zorunlu uyumluluk |
|---|---|---|
| v0.7 → v0.8 | Profil v6, aktif maç v3, telemetri v4, analiz v2, Deste Danışmanı v2 | v5 profil, v2 aktif maç ve bağlamsız eski kayıtlar açılır |
| v0.8 → v0.9 | Profil v7, rekabetçi profil şeması v1, online sonuç protokolü v2 | v6 profil korunur; yerel/P2P geçmişi dereceli rating'e dönüştürülmez |
| v0.9 → v1.0 | Sadece gerekliyse additive şema; launch sırasında gereksiz migration yasaktır | v0.7–v0.9 kayıtları yedekle/migrate et/geri aç döngüsünden geçer |

Bu sürüm numaraları uygulama başlamadan önce mevcut kayıt testleriyle tekrar doğrulanır. Şema yükseltmesi yalnızca gerçekten kalıcı veri değişiyorsa yapılır.

### 4.3 Ortak release kapıları

Her sürümün kendi manifesti ve tek komutlu koşucusu olur. En az şu gruplar korunur:

1. Sürüm sözleşmesi ve release notes.
2. Yeni veri kataloğu ve bozuk veri reddi.
3. Kayıt/profil migration, yedek ve tekrar yükleme.
4. Maç kuralları, AI oynanabilirliği ve deterministik tekrar.
5. Yerel, Steam P2P ve dedicated regressions.
6. Altı dilde kaynak ve gerçek UI ağacı denetimi.
7. 1280×720 temel arayüz; v1.0'da ayrıca hedef Windows çözünürlük matrisi.
8. Üretilmiş export veya server paketinin aynı kritik akışları çalıştırması.

---

# v0.8 — Sınır Hattı

**Sürüm hedefi:** Oyuncunun öğrendiği Kuşatma/Hakimiyet, deste kurma ve karşı hamle bilgisini her hafta değişen ama adil koşullarda kullanmasını sağlamak.

## 5. v0.8 ürün vaadi

Oyuncu ana menüden o haftanın meydan okumasını görür; koşulları, önerilen yaklaşımı ve kozmetik ödülleri anlar; sabit kurallarla AI'a karşı oynar; sonuçta hedef, madalya seviyesi ve maç analizi üzerinden neyi iyi/kötü yaptığını görür. Aynı sürüm, mevcut baskın planlara cevap üreten küçük bir kart seti ekler.

Bu sürümün ana çıktısı yeni bir ana oyun modu değil; **tekrar oynanabilir, içerik odaklı bir taktik döngüdür**.

## 6. v0.8 kapsamı

### 6.1 Haftalık Meydan Okuma kataloğu

Yeni katalog `data/challenges/v0_8_weekly_challenges.json` altında sürümlü veri olarak tutulur. İlk sürüm, canlı uzaktan içerik indirmeden çalışacak şekilde en az **sekiz haftalık** oynanabilir içerik paketiyle çıkar.

Her meydan okuma kaydı aşağıdakileri taşır:

- `challenge_id`, sıra, içerik sürümü, haftalık görünür başlık/açıklama ve etkinlik anahtarı.
- Başlangıç/bitiş zamanı veya offline test için belirlenmiş aktivasyon penceresi.
- Kuşatma ya da Hakimiyet ruleset'i; kuralların sürümü.
- Sabit seed, ilk oyuncu, tur süresi, otomatik saldırı izni ve izinli kart havuzu.
- Oyuncu ile rakip için sabit/izinli deste düzeni, AI zorluğu ve Etki Kartı seçimi.
- Bir ana hedef, en fazla iki isteğe bağlı hedef ve açık başarı ölçümü.
- Skor/madalya eşikleri, ilk tamamlamaya ait kozmetik/Mühür ödülü ve tekrar oynama kuralı.
- Deste Danışmanı için meydan okumaya özel, yargılayıcı olmayan taktik ipucu anahtarları.

Katalog doğrulayıcısı aşağıdaki hataları baştan reddeder:

- Yinelenen kimlik/sıra, geçersiz tarih aralığı, bilinmeyen kart veya Etki Kartı.
- Destede yanlış kart sayısı, desteklenmeyen ruleset, uygunsuz tur süresi ya da eksik seed.
- Ulaşılamaz skor eşiği, aynı hedefi çelişkili biçimde isteyen koşullar.
- Kozmetik dışı güç ödülü veya tekrar oynayarak sınırsız ilk-tamamlama ödülü.
- Bir önceki içerik sürümünü kıracak değişiklikte `content_version` artırılmaması.

### 6.2 Meydan okuma akışı ve arayüz

Ana menüde kalıcı bir **Haftalık Meydan Okuma** giriş kartı bulunur. Kart; aktif başlığı, kalan zamanı, son deneme sonucunu ve varsa alınmış madalyayı gösterir.

Detay ekranı şu bilgileri açıkça gösterir:

- Kurallar: ruleset, tur süresi, otomatik saldırı, sabit deste/izinli değişim alanı ve rakip zorluğu.
- Ana ve yan hedefler; skorun nasıl hesaplandığı; ödülün yalnızca kozmetik olduğu.
- Deste Danışmanı'nın meydan okumaya bağlamlı en fazla üç önerisi.
- Başlat, yeniden dene, geçmiş sonucu gör ve normal oyun modlarına dön eylemleri.

Savaş alanında görünür bir **Meydan Okuma Hedefleri** yüzeyi olur. Bu yüzey canlı hedef ilerlemesini ve skoru gösterir; normal Sefer Hedefleri bileşeniyle aynı görsel/etkileşim standardını kullanır.

Maç sonu ekranı şunları birleştirir:

- Başarılı/başarısız ana hedef ve madalya seviyesi.
- Puanın bileşenleri; belirsiz veya gizli puan cezası yoktur.
- Kritik koridor ve mevcut maç analizi içgörüleri.
- İlk tamamlama ödülü, tekrar ödülü ve profil ilerlemesinin açık ayrımı.
- Aynı meydan okumayı yeni maç kimliğiyle tekrar başlatma seçeneği.

### 6.3 Skor, madalya ve ödül ilkeleri

Madalya sistemi ilk sürümde **Bronz / Gümüş / Altın** olur. Ana hedef tamamlanmadan Altın/Gümüş verilemez; puan, yalnızca oyuncunun görebildiği olaylardan üretilir.

Skor sıralaması aşağıdaki sabit önceliktedir:

1. Ana hedefin tamamlanması.
2. Yan hedef sayısı.
3. Kurala bağlı skor bileşenleri (ör. kalan Merkez canı, Hakimiyet puanı veya hedefe uygun raund verimliliği).
4. Deterministik eşitlik bozucu olarak daha az raund; eşitse aynı madalya paylaşılır.

Ödül yapısı:

- İlk Bronz/Gümüş/Altın için tanımlı bir Mühür miktarı ve en fazla bir kozmetik açılımı.
- Aynı meydan okumayı tekrar oynamak; analiz, kişisel en iyi sonuç ve başarı hissi sağlar; sınırsız Mühür üretmez.
- Kart, kart seviyesi, Enerji, savaş gücü, ranked rating veya zorunlu rekabet avantajı vermez.

### 6.4 Sekiz kartlık karşı-oyun seti

v0.8, yeni ana mekanik veya tepki zinciri eklemez. Kartlar mevcut resolver ve hedefleme dilini kullanır. İlk set için tasarım rolleri:

| Rol | Kart sayısı | Karşılık verdiği plan | Tasarım sınırı |
|---|---:|---|---|
| Geniş saha cevabı | 1 | Aynı koridorda aşırı kart yığma | Tek hamlede bütün oyunu bitirmez |
| Yapı baskısı cevabı | 1 | Korunan yapı/uzun vadeli üretim | Merkez hasarıyla çakışıp aşırı tempo yaratmaz |
| Etki Kartı karşılığı | 1 | Kalıcı Etki Kartı değer zinciri | Etki kartını tamamen anlamsızlaştırmaz |
| Koridor hareketi cevabı | 1 | Sürekli kanat değiştirme veya kaçış | Hareketi kaldırmaz, maliyet/konum kararı yaratır |
| Savunma kırma | 1 | Zırh/iyileştirme/koruma birikimi | Doğrudan öldürme eşiği kontrollü kalır |
| Tempo telafisi | 1 | Erken geriye düşen, oynanabilir ama yavaş deste | Kart çekişi ve Enerji güvenli sınırda kalır |
| Hedef koruma | 1 | Tek yüksek değerli kartı silmeye odaklı plan | Sürekli kilit yaratmaz |
| Esnek teknik kart | 1 | Birden çok match-up'ta sınırlı fayda | Her destede zorunlu olmayacak kadar dar kalır |

Her kart için aşağıdakiler aynı teslimde yapılır:

- Kart verisi, görseli, açıklaması, altı dil metni ve Kart Galerisi görünümü.
- Gerçek resolver üzerinden unit/rules smoke testi; illegal hedef, sıra/faz, Enerji, snapshot ve AI davranışı denetimi.
- Deste Danışmanı'nın rol/mekanik değerlendirmesine dahil edilmesi.
- Mevcut starter desteleri ve yeni kartla kurulan en az bir örnek deste için öneri doğrulaması.
- Kart başına başlatılabilirlik, tetiklenme, kazanma sinyali ve ilk/ikinci oyuncu dağılımının raporlanması.

### 6.5 Telemetri ve analiz genişlemesi

Telemetri v4, mevcut maç verisini silmeden meydan okuma bağlamı ekler:

- `challenge_id`, içerik/kurallar sürümü, skor, madalya, ana/yan hedef sonucu.
- Hedef bazında ilerleme olayları ve denemeyi bitiren koşul.
- Deneme türü: ilk deneme, yeniden deneme veya geçmiş içerik denemesi.
- Kart seti/metaya ait dengeli, kişisel veri içermeyen olaylar.

Maç Analizi v2:

- Genel Kuşatma/Hakimiyet açıklamasını korur.
- Meydan okumasında yalnızca telemetri kanıtlıysa hedefe neden yaklaşıldığını veya neden kaçırıldığını açıklayan en fazla iki ek içgörü verir.
- Hedefe ulaşılamayan ama veri zayıf olan durumda kesin nedensellik iddiası kurmaz.

Deste Danışmanı v2:

- Meydan okuma bağlamına göre desteklenen rol eksiklerini gösterir.
- Oyuncuyu tek bir "doğru" desteye zorlamaz.
- Meydan okumanın sabit desteli olduğu haftalarda deste önerisi yerine oynanış odağı verir.

### 6.6 Kayıt ve profil davranışı

Profil v6 içinde meydan okuma durumu ayrı bölümde tutulur:

- Her `challenge_id` için en iyi skor, en iyi madalya, ilk tamamlama kimliği, ödül alınma durumu ve son deneme özeti.
- Katalog içeriğinin tamamı profile veya aktif maç snapshot'ına kopyalanmaz; yalnızca kararlı bağlam yazılır.
- Aynı maç sonucu yeniden işlendiğinde ödül ve en iyi skor yanlışlıkla iki kez yazılmaz.
- Steam Cloud birden fazla cihazda kişisel en iyi sonucu ve kozmetiği güvenli birleştirir; cloud verisi ranked sonucu sayılmaz.

Aktif maç v3, meydan okuma bağlamını devam ettirir. Kayıt geri yüklendiğinde doğru hedef, skor kuralları ve içerik sürümü görünür; içerik artık desteklenmiyorsa oyuncuya açık hata/geri dönüş sunulur.

### 6.7 v0.8 kapsam dışı

Bu sürüm özellikle aşağıdakileri içermez:

- Dereceli kuyruk, rating, global leaderboard, sezon sıralaması veya ranked ödülü.
- Uzaktan canlı içerik yönetimi, CMS veya içerik indirme servisi.
- Yeni üçüncü ana ruleset, tepki zinciri, kart paketi/lootbox ekonomisi veya kart satın alma.
- P2P maç sonucunu rekabetçi sonuç kabul etme.
- Yeni mobil platform çıkışı ya da çapraz platform dereceli eşleştirme.

## 7. v0.8 milestone planı

| Milestone | Teslim | Çıkış ölçütü |
|---|---|---|
| **M0 — Sözleşme** | Meydan okuma veri şeması, doğrulayıcı, MatchSetup bağlamı ve migration tasarımı | Hatalı katalog reddedilir; normal/AI/online kurulum eski meydan okuma bağlamını temizler |
| **M1 — Oynanabilir döngü** | Sekiz haftalık katalog, menü/detay/savaş alanı/sonuç yüzeyleri, kayıt | İlk meydan okuma başlatılır, kaydedilir, yeniden yüklenir, tekrar oynanır ve ilk ödül tek kez verilir |
| **M2 — Karşı oyun** | Sekiz kart, resolver/AI/Deste Danışmanı/Kart Galerisi entegrasyonu | Yeni kartlar mevcut kuralları bozmadan gerçek maçta kullanılabilir; öneriler açıklanabilirdir |
| **M3 — Ölçüm ve denge** | Telemetri v4, Analiz v2, kart ve meydan okuma denge koşuları | Her meydan okuma en az 12 deterministik üretim-AI koşusunda tamamlanabilir; kart başına en az 12 odak maç ölçülür |
| **M4 — RC** | v0.8 manifesti, release notes, çeviri/online/kayıt regresyonları | Tüm kapılar geçer; export edilen build kritik meydan okuma ve kayıt akışlarını çalıştırır |

### v0.8 RC kabul kriterleri

- Sekiz meydan okumanın tamamı katalog doğrulamasından geçer ve hedefleri gözlenebilir biçimde tamamlanabilir.
- Hiçbir meydan okuma normal, AI, Steam P2P veya dedicated maçın bağlamını kirletmez.
- İlk tamamlamaya ait ödül, aynı `match_id` veya yeniden yükleme ile tekrar verilmez.
- Minimum 96 meydan okuma AI koşusu ve en az 96 yeni-kart odak maçı; geçersiz AI hamlesi/yarım maç/zaman aşımı sıfırdır.
- Mevcut Kuşatma, Hakimiyet, Etki Kartı, kampanya, kayıt ve online RC eşikleri tekrar geçer.
- Altı dilde katalog, madalya, skor, sonuç ve Deste Danışmanı metinleri gerçek seçili dil UI ağacında doğrulanır.

### v0.8 go/no-go kararı

v0.9'a geçmeden önce şu kararlar kapatılır:

- En az iki ayrı test turunda meydan okumaların anlaşılabilirliği ve medal hedeflerinin makullüğü doğrulanır.
- Sekiz karşı-oyun kartından zorunlu/ezici görünenler için ikinci örneklem alınır; küçük örneklemde yalnızca gözlem nedeniyle değer değişmez.
- Oyuncuların dereceli sıraya mı, daha fazla PvE içeriğine mi öncelik verdiği test/geri bildirimle netleşir. Dereceli beta kararı teknik hazırlıktan ayrı bir ürün kararıdır.

---

# v0.9 — Sezon 0: Rekabetçi Temel

**Sürüm hedefi:** Darwine'da ilk kez, sonucu istemcinin veya Steam Cloud'un değiştiremediği, sınırlı ama güvenilir bir dereceli sezon yürütmek.

## 8. v0.9 ürün vaadi

Oyuncu Steam hesabıyla yarışmaya uygunluğunu doğrular, sabit kurallı dereceli Kuşatma kuyruğuna girer, dedicated sunucuda eşleşir, bağlantı kesilse bile tanımlı kuralla maçı bitirir ve sonucu derecesine güvenilir biçimde yansır. Sezon ekranı ilerlemeyi, zamanlamayı ve yalnızca kozmetik ödülleri açıkça gösterir.

Bu sürüm **"Ranked Beta / Sezon 0"** olarak çıkar. Amaç sınırsız ölçekli bir e-spor platformu değil; doğru otorite modelinin gerçek oyuncu yükünde kanıtlanmasıdır.

## 9. v0.9 kapsamı

### 9.1 Trusted competitive mimarisi

Dereceli akış, Godot istemcisi veya Steam Cloud içine yerleştirilmez. Yeni bir backend/dedicated katmanı gerektirir:

| Bileşen | Sorumluluk | Güven sınırı |
|---|---|---|
| Steam kimlik doğrulama servisi | Kullanıcının sahip olduğu Steam kimliğini doğrular, kısa ömürlü oturum üretir | İstemci kimliği doğrudan kabul edilmez |
| Eşleştirme servisi | Kuyruk bileti, bölge, kurallar sürümü, rating aralığı ve sunucu ataması | İstemci kendine rakip/sunucu seçemez |
| Dedicated oyun sunucusu | Kart kuralları, sıra, hedef, reconnect, hükmen sonuç ve maç olayı otoritesi | Hamle dışında istemci yazımı kabul edilmez |
| Sonuç alma servisi | Sunucudan imzalı/doğrulanabilir sonuç alır, tekrarları idempotent işler | İstemci sonuç yazamaz |
| Rekabetçi veri deposu | Rating, maç geçmişi, sezon durumu, ceza ve ödül kayıtları | Yazma denetimli/audit log'ludur |
| Operasyon yüzeyi | Sunucu sağlığı, kuyruk süresi, hata oranı, maç sonucu ve manuel inceleme | Oyuncu verisini değiştirme yetkisi rol bazlıdır |

Dedicated sunucu yalnızca doğrulanmış bir oturumla açılmış ranked maçı kabul eder. Maç bittiğinde, sonuç servisine en az `match_id`, ruleset/sürüm, iki doğrulanmış hesap kimliği, başlangıç deck hash'i, bitiş nedeni, revision zinciri ve server-side sonuç özeti gönderilir.

### 9.2 Dereceli kurallar — Sezon 0

İlk dereceli sezon kapsamı bilinçli olarak dardır:

- **1v1 Kuşatma** tek dereceli ruleset'tir. Hakimiyet, yerel/AI/casual/özel odada kalır; verisi yeterince olgunlaşmadan ranked havuza girmez.
- Her oyuncu kuyruk öncesi geçerli 30 kartlık destesini seçer. Deste, kuyruk bileti kesildikten sonra değiştirilmez.
- Kurallar sabittir: tur süresi, otomatik saldırı seçeneği, etkin kart havuzu ve `ruleset_version` sezon boyunca sunucu tarafında tanımlanır.
- İlk sezonun kart havuzu, v0.8 sonunda denge raporuyla dondurulur. Acil bozukluk dışında canlı maç ortasında kart değeri değiştirilmez.
- P2P, davet kodu ve arkadaş lobisi **casual** kalır; hiçbir şekilde ranked rating'e yazmaz.
- Dedicated maça yeniden bağlanma mevcut 90 saniyelik modelle başlar; ceza/hükmen sonuç yalnızca sunucu sonucu olarak yazılır.

### 9.3 Eşleştirme ve rating

Sezon 0 için anlaşılabilir, desteklenebilir bir sistem tercih edilir:

- Yeni oyuncu başlangıç rating'i alır ve **5 placement maçı** sonunda ilk ligi görünür olur.
- Rating güncellemesi sunucu sonucuyla bir kez uygulanır; maç iptaliyse rating değişmez.
- Görünen ligler: **Demir, Bronz, Gümüş, Altın, Usta**. Gerekirse alt kademeler rating aralığıyla ayrılır; kullanıcıya puan değişiminin nedeni gösterilir.
- Eşleştirme ilk olarak yakın rating aralığını dener; bekleme arttıkça aralığı kademeli genişletir. Genişletme, sunucu ve UI'da görünür kuralla yapılır.
- Bölge seçimi/varsayılanı backend yapılandırmasıdır. Yüksek gecikme nedeniyle yanlış bölgede eşleşme, oyun içi ping ölçümü ve destek akışıyla izlenir.
- MMR/rating değeri istemcide yalnızca görüntülenir; profil içindeki `competitive` önbelleği backend gerçeğinin yerine geçmez.

Rating formülü M0'da yazılı ve testlenmiş hâle getirilir. Sezon 0 boyunca formül, geriye dönük açıklamasız değiştirilmez. Büyük sistem değişikliği için sezon sıfırlaması veya ayrı bir sezon gerekir.

### 9.4 Maç yaşam döngüsü ve kötüye kullanım kuralları

Her ranked maç şu görünür durumlardan geçer:

1. Kimlik doğrulama ve kuyruk bileti.
2. Rakip/sunucu ataması ve deck hash doğrulaması.
3. Bağlantı, mulligan, aktif maç, reconnect bekleme veya bitiş.
4. Otoriter sonuç ve idempotent rating güncellemesi.
5. Oyuncuya gösterilen sonuç, rating değişimi, sezon ilerlemesi ve varsa kozmetik ödül.

Tanımlanacak kurallar:

- İki oyuncu bağlanmadan önce başarısız olan eşleşme iptal edilir; rating değişmez.
- Maç sırasında kopan oyuncu için server-side 90 saniyelik pencere uygulanır.
- Süre dolunca bağlı oyuncu hükmen kazanır; iki oyuncu yoksa maç iptal edilir.
- İstemci kapanması, paket tekrarı, sonuç tekrar gönderimi ve sunucu yeniden başlatması çift sonuç doğurmaz.
- Sık iptal/kopma davranışı için ilk sürümde görünür uyarı ve kısa kuyruk gecikmesi uygulanabilir; kalıcı ceza yalnızca gözlemlenmiş veri ve destek politikasıyla etkinleştirilir.
- Hile şüphesi veya teknik uyuşmazlıkta hamle günlüğü, server revision zinciri ve sonuç audit kaydı korunur.

### 9.5 Rekabetçi profil ve sezon arayüzü

Profil v7, backend kaynaklı rekabetçi bölümü taşır:

- Doğrulanmış hesap kimliği, mevcut sezon kimliği, placement durumu, rating, lig, en yüksek lig, sezon maç sayısı ve güvenli son sonuç özeti.
- Sonuç yazım zamanı, backend revizyonu ve istemciye gösterilebilecek hata/durum alanı.
- Sezon ödül sahipliği ve bunların kozmetik envantere idempotent aktarımı.

Arayüz yüzeyleri:

- Ana menüde **Dereceli Sezon 0** kartı: sezon bitişi, lig, placement ve kuyruk durumu.
- Dereceli hazırlık: seçili deste, kurallar, bağlantı gereksinimi, iptal ve bekleme bilgisi.
- Eşleşme durumu: arama süresi, genişleyen rating aralığı ve vazgeçme eylemi.
- Maç sonucu: doğrulanmış sonuç, rating değişimi, bitiş nedeni ve sezon ilerlemesi.
- Profilde rekabetçi özet ve son doğrulanmış maçlar. Yerel/Steam Cloud geçmişi ile server history etikette ayrılır.

### 9.6 Sezon takvimi, ödüller ve operasyon

- Sezon 0 süresi backend yapılandırmasından yönetilir; istemci sabit tarihe güvenmez.
- Sezon başlangıcı, kapanışı, bakım modu, kart havuzu, ruleset sürümü ve ödül tablosu sunucu tarafından imzalı/versiyonlu konfigürasyonla gelir.
- Sezon ödülleri yalnızca unvan, sancak, profil çerçevesi ve görünüm gibi kozmetiklerdir.
- Ödül verme; sezon sonu tekrar çalıştırıldığında veya istemci yeniden bağlandığında iki kez oluşmaz.
- Operasyon panosu en az kuyruk uzunluğu, eşleşme süresi, maç bitiş nedeni, reconnect oranı, sonuç yazma hatası, sunucu sağlığı ve sürüm uyumsuzluğunu gösterir.
- Yedekleme, veri saklama süresi, silme/erişim talebi ve destek inceleme akışı v1.0 öncesinde yazılı hâle getirilir.

### 9.7 v0.9 kapsam dışı

- Birden fazla ranked ruleset, turnuva braketi, takım modu, spectator yayını veya replay paylaşım ağı.
- Paket/lootbox ekonomisi, ücretli güç, kart satışı veya pazar yeri.
- Mobil/çapraz platform ranked eşleştirme.
- P2P host migration'ı ranked çözümü olarak kullanmak.
- Sezon 0 verisi olmadan geniş kapsamlı lig resetleri veya ceza otomasyonu.

## 10. v0.9 milestone planı

| Milestone | Teslim | Çıkış ölçütü |
|---|---|---|
| **M0 — Rekabet sözleşmesi** | Kimlik, queue, result, rating ve veri saklama sözleşmeleri; tehdit/abuse modeli | İstemci, Cloud ve backend yetkileri açıkça ayrılır; sonuç şeması versiyonlanır |
| **M1 — Trusted sonuç hattı** | Steam doğrulama, dedicated atama, imzalı sonuç alma, idempotent veritabanı yazımı | Aynı sonuç iki kez rating/ödül yazmaz; istemci yazımı reddedilir |
| **M2 — Oynanabilir ranked beta** | Kuyruk, deck hash, 1v1 Kuşatma, reconnect/hükmen sonuç, client UI | İki gerçek istemci eşleşir, reconnect olur, sonuç güvenilir biçimde profile döner |
| **M3 — Sezon ve operasyon** | Placement, lig/rating, sezon ekranı, kozmetik ödül, izleme/alert yüzeyi | Sezon başlangıç/kapanış/ödül akışı idempotent ve izlenebilirdir |
| **M4 — Kapalı beta ve RC** | Yük, kötüye kullanım, migration, destek runbook'u, release manifesti | Kontrollü oyuncu grubunda P0/P1 olmadan hedeflenen tamamlanmış maç oranı sağlanır |

### v0.9 RC kabul kriterleri

- Ranked sonucu, yalnızca listedeki dedicated/backend yolundan gelir; Steam Cloud veya local profile enjeksiyonu rating'i değiştiremez.
- Her `match_id` için tek sonuç, tek rating güncellemesi ve tek sezon ödül kaydı vardır.
- İstemci tarafı `load`, `snapshot`, `restore`, stat/rating yazma ve başka hesaba ait sonuç isteğiyle başarı elde edemez.
- Eşleştirme, iki oyuncu, kopma/geri dönüş, hükmen kazanma, iki tarafın kopması, server restart ve çift sonuç gönderimi uçtan uca test edilir.
- Rating formülü, placement, sezon kapanışı ve ödül hesaplama saf/testlenebilir fonksiyonlarla denetlenir.
- En az 100 kontrollü dedicated match; sonuç kaybı, çift sonuç ve çözülmemiş P1 yoktur. Yük testi hedefi, seçilen sunucu kapasitesiyle M0'da sabitlenir.
- Kişisel veri, log ve destek erişimi için saklama/erişim politikası bulunur; gizli token veya reconnect anahtarı istemci loguna yazılmaz.
- Altı dilde kuyruk, hata, sonuç, lig ve sezon metinleri; gerçek UI ağacında doğrulanır.

### v0.9 go/no-go kararı

v1.0 RC'sine geçiş için:

- Sezon 0 boyunca duplicate sonuç, rating geri sarma veya doğrulanamayan maç olmamalıdır.
- Sunucu maliyeti, eşleşme süresi, reconnect oranı ve destek yükü ölçülür; sürdürülebilir operasyon kapasitesi onaylanır.
- Kart havuzu, yalnızca veriye dayalı küçük denge değişiklikleriyle launch için dondurulabilir durumda olmalıdır.
- Dereceli beta sorunluysa v1.0'da casual/campaign deneyimini engellemeden "beta" etiketiyle kalabilir; tam sürüm etiketi güvenilir olmayan rankedi gizlemez.

---

# v1.0 — Darwine Tam Sürüm

**Sürüm hedefi:** Darwine'ın ilk tam sürümünü; öğretilebilir, tekrar oynanabilir, güvenilir çevrimiçi seçeneği olan ve Steam'de bakım yapılabilir bir ürün olarak yayınlamak.

## 11. v1.0 yayın tanımı

v1.0; her olası özellik fikrinin bitmesi değildir. Aşağıdaki deneyimin eksiksiz ve güvenilir olmasıdır:

1. Oyuncu oyunu başlatır, dilini/ayarını seçer, ilk maç öğretimini tamamlar.
2. Sefer, AI, yerel maç, casual online ve Haftalık Meydan Okuma arasında kaybolmadan geçer.
3. Deste kurar, Deste Danışmanı ve maç analiziyle neden-sonuç ilişkisini anlayabilir.
4. Kaydı güvenle devam ettirir, yedekten döner ve Steam Cloud ile cihaz değiştirir.
5. İsterse Sezon 0/1 kurallarındaki dereceli akışa açık gereksinimlerle girer.
6. Oyun; desteklenen Windows/Steam ortamında, izlenebilir hatalar ve yayın sonrası müdahale planıyla çalışır.

## 12. v1.0 kapsamı

### 12.1 Oyun içeriği ve mod matrisi

| Yüzey | v1.0 taahhüdü | Not |
|---|---|---|
| İlk Maç Öğretimi | Tam ve atlanabilir öğretim; temel kontroller ve tur akışı | Mevcut öğretim, gerçek UI testleriyle kapanır |
| Komutan Seferi | Altı senaryo, ilerleme, hedefler, kayıt ve analiz | v0.7 içeriği korunur; v1.0'da kırılmaz |
| Haftalık Meydan Okuma | v0.8'in en az sekiz içerik paketi ve geçmiş içerik erişim kuralı | Uzaktan içerik ancak ayrıca onaylanırsa eklenir |
| AI / Yerel | Kuşatma ve Hakimiyet, üç zorluk, belirlenmiş ayarlar | Yeni kurallar eski modları bozmamalı |
| Casual Online | Steam P2P, davet/lobi ve kodlu UDP/dedicated seçenekleri | Casual sonuçları ranked sonucu değildir |
| Dereceli | v0.9'da doğrulanan tek ruleset/kart havuzu/sezon modeli | Operasyonel güven gerçekleşmezse beta etiketi korunur |
| Deste / Kart Galerisi | Starter desteler, kayıtlı desteler, Kart Galerisi, Deste Danışmanı | Launch card pool içerik dondurmasından sonra değişmez |

Launch kart havuzu için sayı değil **okunabilir strateji kapsamı** hedeflenir: her starter deste birincil planını oynayabilmeli; geniş saha, yapı, Etki Kartı, hareket, savunma ve tempo planlarının en az bir uygulanabilir cevabı olmalı; hiçbir teknik kart bütün destelerde zorunlu olmamalıdır.

### 12.2 Başlangıç, UX ve erişilebilirlik

- İlk açılışta dil, ses, görüntü, otomatik saldırı ve temel kontrol tercihleri erişilebilir olur.
- Yeni oyuncu; Sefer, AI, casual online, Weekly Challenge ve ranked seçeneklerinin amacını/erişim koşulunu ayırt eder.
- Tüm maç içi eylemler için geçerli/geçersiz hedef, faz, Enerji, reconnect ve hata mesajları açık olur.
- Klavye/fare odak sırası, Escape/geri dönüş, ekran okuyucuya yardımcı anlamlı node adları ve ölçeklenebilir metin için erişilebilirlik kontrol listesi tamamlanır.
- 1280×720 minimum tasarım yüzeyi korunur; desteklenen Windows çözünürlükleri için taşma, kesilme ve dokunulabilir hedef denetimi yapılır.
- Görsel efekt, ses, titreşim varsa bunlar ayarlardan azaltılabilir/kapatılabilir olur.

### 12.3 Performans ve stabilite

v1.0 M0'da hedef Windows minimum/önerilen donanım matrisi gerçek ölçümle belirlenir. Yayından önce:

- Tanımlı minimum makinede hedef çözünürlükte kabul edilen kare hızı ve frame-pacing bütçesi yazılıdır.
- Açılış, ana menü, Deste Atölyesi, maç başlangıcı, kart oynama, yoğun savaş alanı, sonuç ekranı ve tekrar yükleme profillenir.
- Bellek artışı, uzun oturum, sahne tekrar yükleme, audio kaynakları ve ağ kopma/geri dönüş için soak testi yürütülür.
- P0 çökme, veri kaybı, kilitlenme veya oyun sonucunu bozan P1 bilinen sorun olarak yayınlanmaz.
- Crash/hata raporlama, kullanıcı onayı ve gizlilik politikasıyla uygulanır; ham reconnect token, Steam auth ticket veya gizli veri rapora düşmez.

### 12.4 Kayıt, Cloud ve hesap dayanıklılığı

- Profil, aktif maç, seçili deste, ayar, sefer ve meydan okuma verileri atomik yazım ve yedek davranışını korur.
- v0.7, v0.8 ve v0.9 örnek kayıtları launch build ile migrate edilir ve yeniden yüklenir.
- Steam Cloud uyuşmazlığı; oyuncunun ilerlemesini sessizce silmeden, açık durum ve güvenli son geçerli belgeyle ele alınır.
- Ranked rekabet verisi Cloud kopyasından değil backend'den görüntülenir; Cloud kapalıyken casual/yerel oyun oynanabilir kalır.
- Sunucu tarafındaki ranked sonuç, sezon ödülü ve destek denetimi için ayrı yedekleme/geri yükleme prosedürü bulunur.

### 12.5 Steam ve yayın paketi

v1.0'ın resmi oyuncu platformu **Windows x86_64 / Steam** olur. Linux dedicated server paketi ayrı operasyonel teslimdir. Diğer istemci platformları, aynı kalite matrisini geçmedikçe v1.0 yayın taahhüdüne dahil edilmez.

Steam teslim kontrol listesi:

- Gerçek Steam App ID, üretim depot ayarları ve `steam_appid.txt` dosyasının geliştirme/production ayrımı.
- Steamworks başarımları, INT istatistikleri, görünen ad/açıklamalar ve kilitli/açık ikonlar.
- Steam Cloud kota/doğrulama ayarları; fallback'ın işe yaradığı export build testi.
- Overlay, arkadaş daveti, Rich Presence ve deep-link ile katılımın Steam dışı/failure durumlarıyla birlikte testi.
- Depot build'i, temiz Windows makine kurulumu, güncelleme/rollback ve sürüm uyumluluğu denetimi.
- Store varlıkları, destek iletişim kanalı, gizlilik politikası, EULA/içerik derecelendirme ve bilinen sorunlar sayfası.

### 12.6 Canlı operasyon ve destek

- Launch öncesi **runbook**: dedicated server başlatma/yeniden başlatma, kapasite, log toplama, bakım modu, sezon durdurma, sonuç gecikmesi ve rollback.
- Uyarılar: server health, kuyruk süresi, sonuç yazım başarısızlığı, reconnect artışı, sürüm uyumsuzluğu ve crash artışı.
- Destek akışı: kayıt kurtarma, Cloud anlaşmazlığı, casual bağlantı sorunu, ranked sonuç itirazı ve hesap erişimi.
- Olay yönetimi: P0/P1 sınıfları, sorumlu kişi, oyuncuya durum mesajı, hotfix yolu ve postmortem kaydı.
- 1.0 sonrası ilk iki hafta için günlük sağlık kontrolü; ilk sezon/haftalık meydan okuma içerik takvimi önceden hazırlanır.

### 12.7 İçerik ve kapsam dondurması

v1.0 RC başladıktan sonra yalnızca şu değişiklikler yapılabilir:

- P0/P1 hata düzeltmesi, doğrulanmış exploit kapatması, çeviri/hata metni düzeltmesi.
- Ölçümle kanıtlanan küçük kart sayısal ayarı; yeni mekanik veya yeni kart ailesi değil.
- Yayın altyapısı, build, depot ve server konfigürasyon düzeltmesi.

Aşağıdakiler v1.0 sonrası değerlendirilir:

- Yeni ana ruleset, tepki zinciri, turnuva sistemi, spectator/replay ağı.
- Yeni platform istemcileri ve cross-platform ranked.
- Paket ekonomisi, ücretli içerik, pazar yeri veya başka monetization modelleri.
- Büyük kart seti genişlemesi veya sezon ortasında meta sarsacak içerik.

## 13. v1.0 milestone planı

| Milestone | Teslim | Çıkış ölçütü |
|---|---|---|
| **M0 — Launch sözleşmesi** | Platform matrisi, minimum donanım, sürüm/ruleset matrisi, release checklist ve ownership | Ne yayınlandığı, neyin beta kaldığı ve neyin desteklenmediği yazılıdır |
| **M1 — Deneyim kapanışı** | İlk saat UX, erişilebilirlik, sefer/challenge/deck/profile sınır kontrolleri | Yeni oyuncu temel döngüyü yardım istemeden tamamlar; kritik UI taşması yoktur |
| **M2 — İçerik ve denge donması** | Launch kart havuzu, starter desteler, oyun modu regresyonları ve son denge raporu | Veriye dayalı donma kararı alınır; yeni mekanik çalışması durur |
| **M3 — Steam ve operasyon** | Production depot, Steamworks, build/release prosedürü, server/backend runbook ve observability | Temiz makine/export/dedicated paketleri uçtan uca doğrulanır |
| **M4 — Launch RC** | Uzun süreli QA, performans, migration, güvenlik/abuse regresyonu ve release candidate | P0/P1 sıfır; tüm launch kapıları ve go-live tatbikatı geçer |

## 14. v1.0 release kapıları

### 14.1 İşlevsel kapılar

- İlk maç, Sefer, AI, yerel, casual P2P, kodlu dedicated, Haftalık Meydan Okuma, kaydet/yükle ve Deste Atölyesi uçtan uca çalışır.
- Ranked yalnızca v0.9 güven koşulları sağlanmışsa tam yüzey olarak görünür; aksi hâlde açık "beta" etiketi ve doğru destek mesajı taşır.
- Aktif maç/yedek/Cloud migration testleri v0.7–v1.0 örnekleriyle geçer.
- Tüm görünür release notes sürümle, depot build numarasıyla ve oyun içi sürümle tutarlıdır.

### 14.2 Denge kapıları

- Kuşatma, Hakimiyet, kampanya, meydan okuma ve Etki Kartı paketleri için güncel deterministic suite çalışır.
- Her yeni/son değiştirilmiş kart; tetiklenme, kazanma sinyali, ilk/ikinci oyuncu ayrımı ve beklenmeyen resolver hatası açısından raporlanır.
- Ranked havuzundaki değerler, sezon boyunca sabitlenmiş ruleset sürümüne bağlanır.
- Şüpheli sinyalde önce bağımsız ikinci örneklem alınır; eşik sadece sonucu beğenmek için gevşetilmez.

### 14.3 Kalite kapıları

- Desteklenen dil/çözünürlük matrisi gerçek UI ağacı üzerinden geçer.
- Tanımlı minimum donanımda performans hedefi ve uzun oturum stabilitesi sağlanır.
- Temiz Windows kurulumunda Steam build, Cloud, Overlay, davet, offline fallback ve update/rollback testi geçer.
- Dedicated paket, server restart, reconnect, sonuç hattı ve gözlemleme runbook'u ile doğrulanır.
- P0/P1 açık hata yoktur; P2'ler yayın notu/önceliği ile kabul edilmiştir.

### 14.4 Go-live tatbikatı

Yayın öncesi en az bir kez şu süreç başlangıçtan sona prova edilir:

1. RC build oluşturma ve sürüm sözleşmesi denetimi.
2. Steam staging depot'a yükleme ve temiz makinede kurulum.
3. Dedicated/backend staging açma; casual ve ranked ayrı akış denemesi.
4. Bir server restart, bir reconnect, bir sonuç gecikmesi ve bir Cloud uyuşmazlığı tatbikatı.
5. İzleme/uyarıların tetiklenmesi; destek prosedürünün uygulanması.
6. Rollback ve oyuncuya durum mesajı verme kararı.

## 15. Risk kaydı ve önleme planı

| Risk | Etki | Önleme / karar |
|---|---|---|
| Haftalık içerik statik kalır ve oyuncu hızla tüketir | v0.8 tekrar oynama düşer | Sekiz haftalık içerik, geçmiş içerik kuralı ve v1.0 sonrası içerik takvimi; uzaktan CMS yalnızca ihtiyaç kanıtlanırsa |
| Yeni kartlar meta dengesini bozar | Casual/ranked adaleti bozulur | Küçük set, gerçek resolver testi, yeterli örneklem, v0.9 öncesi kart havuzu donması |
| Steam Cloud rekabet verisi gibi kullanılır | Hile/yanlış rating | Cloud'u sadece eşitleme olarak tutmak; ranked sonucu trusted backend'den almak |
| Dedicated sunucu vardır ama kuyruk/sonuç servisi yoktur | "Ranked" etiketi gerçekte güvenilmez olur | v0.9 M0'da ayrı backend sözleşmesi; v1.0'a geçmeden uçtan uca beta |
| Sürüm sonunda fazla özellik eklenir | RC uzar, kalite düşer | Her sürümün kapsam dışı listesi; launch RC'de yalnızca düzeltme |
| Çeviri anahtarları var ama UI'da sabit metin kalır | Dil desteği eksik görünür | CSV denetiminin yanında seçili locale UI smoke testleri |
| Server operasyonu tek kişiye bağımlı kalır | Launch kesintisi uzar | Runbook, alarm, yedekleme ve go-live tatbikatı |

## 16. Başarı ölçümü

Bu metrikler oyuncu gizliliğini koruyan, toplulaştırılmış ve ürün kararını destekleyen biçimde izlenir. Kesin hedefler beta/ölçüm sonrası ayrı bir operasyon belgesinde onaylanır.

| Alan | v0.8 işareti | v0.9 işareti | v1.0 işareti |
|---|---|---|---|
| Oynanabilirlik | Meydan okuma denemesi/tamamlanması ve hedef anlaşılabilirliği | Tamamlanan ranked maç oranı | Tüm ana modlarda tamamlanan maç/kayıt akışı |
| Denge | Kart tetiklenmesi, first-player farkı, aşırı güçlü/zayıf sinyali | Ranked kart/deck dağılımı ve maç uzunluğu | Launch havuzunda açıklanabilir, izlenebilir meta |
| Güvenilirlik | Kayıt/yeniden yükleme başarısı | Duplicate sonuç, reconnect ve result-write başarısı | Crash, P0/P1, build/server health ve destek yükü |
| Kullanılabilirlik | Hedef ekranı/sonuç anlaşılabilirliği | Queue/rating/sonuç açıklığı | İlk saat akışı, dil/çözünürlük ve erişilebilirlik |
| Operasyon | Statik içerik paketlerinin güvenli sürümlemesi | Kuyruk/sonuç/sunucu izleme | Depot, rollback, runbook ve canlı ilk hafta sağlığı |

## 17. Uygulama sırası ve sahiplik

Her milestone aşağıdaki sırayla ilerler:

1. Kapsam ve kabul kriteri yazılır.
2. Veri sözleşmesi ve migration planı onaylanır.
3. Oyun kuralları/resolver ve persistence entegrasyonu yapılır.
4. UI, yerelleştirme ve oyuncu geri bildirimi eklenir.
5. Deterministik testler, mevcut regresyonlar ve package/export doğrulaması çalışır.
6. Denge/operasyon raporu yazılır; bir sonraki milestone için karar alınır.

Belgedeki hedefler; ölçüm, teknik bağımlılık veya ürün yönü değiştiğinde revize edilebilir. Ancak bir sürüm RC'ye girdikten sonra kapsam genişletilmez; yeni fikir takip eden sürüm veya 1.0 sonrası plan için ayrılır.

## 18. İlk uygulanacak iş

Bu yol haritasının ilk somut işi **v0.8 M0 — Haftalık Meydan Okuma sözleşmesi**dir:

1. `data/challenges/v0_8_weekly_challenges.json` şeması ve sekiz içerik taslağı.
2. Ayrı katalog doğrulayıcısı ve meydan okuma bağlamını `MatchSetup` ile aktif-maç kaydına taşıma.
3. Profil v6 migration tasarımı; ödül idempotency ve kişisel en iyi sonuç sözleşmesi.
4. Bu katman için smoke testleri; normal/AI/online kurulumlarda bağlam temizliği.

M0 doğrulanmadan meydan okuma ekranı veya yeni kartların UI üretimine başlanmaz.
