# Darwine Kayıt, Kurtarma ve Etki Kartları

Bu belge profil önbelleği, aktif maç snapshot'ı, çevrimiçi otorite ve maç-geneli Etki Kartlarının tek kaynaklı çalışma kurallarını özetler. Maç kuralı `GameManager` ve merkezi resolver'larda; sunum `BattlefieldUI` içinde kalır.

## Profil kaydı ve çevrimiçi eşitleme

Yerel profil `user://darwine_profile.json` dosyasında şema sürümü 4 ile tutulur. Yazma işlemi geçici dosya + atomik yer değiştirme kullanır ve üç yedek döndürür. Ana dosya okunamazsa yedekler sırayla denenir; eski şemalar migration geçmişi korunarak güncellenir.

Profil; komutan adı, seviye/XP/mühür, istatistikler, başarılar, görevler, kozmetikler, son 30 benzersiz maç, desteler ve ayar önbelleğini taşır. `DeckManager` ve `SettingsManager` kendi yerel depoları olmaya devam eder; `ProfileRepository` bu bölümlerin çevrimdışı/senkronize önbelleğini izler.

`ProfileSyncProvider` gerçek hesap/back-end adaptör sözleşmesidir. Varsayılan sağlayıcı kullanılamaz durumdadır; yerel JSON hiçbir zaman sahte çevrimiçi profil diye sunulmaz. Gerçek sağlayıcı aşağıdaki güvenleri sağlamalıdır:

- Para birimi, ödül, ilerleme, başarı/görev ve rekabetçi istatistiklerde `server_authoritative=true` yanıtı zorunludur.
- Açılmış unvan ve sancaklar birleşim kümesiyle birleştirilir.
- Maç geçmişi `match_id` ile tekilleştirilir.
- Ayar ve deste bölümlerinde en büyük `updated_at_unix` kazanır.
- Komutan adı kendi değişiklik zamanı ile çözülür.
- Çevrimdışı değişiklikler `operation_id == idempotency_key` olan, en fazla 256 kayıtlı kuyrukta kalır. Yalnızca sağlayıcının açıkça onayladığı işlem kimlikleri kuyruktan çıkarılır.

## Yerel/AI aktif maç kaydı

Adlandırılmış aktif maç slotları `user://darwine_saves/slot_<id>.json` altında tutulur. Şema sürümü 2, uyumluluk sınırı mevcut oyun sürümünün major+minor bölümüdür. Her slot atomik yazılır ve kendine ait son üç geçerli yedeği saklar. Önceki `user://darwine_active_match.json` kaydı da **Eski Otomatik Kayıt** olarak listelenmeye devam eder.

Yeni yerel/AI maç `autosave` slotuyla başlar. Duraklatma menüsündeki **KAYDET** ve **YÜKLE** eylemleri kayıt arşivini açar. Yeni bir slot adı yeni kayıt oluşturur; mevcut slot seçiliyken kaydetmek o slotun güvenli yedek zincirini koruyarak üzerine yazar. Etki Kartı seçimi, mulligan ilerlemesi, kabul edilen enerji/kart/hareket/etki/yıkım/geliştirme hamleleri, tur ve faz geçişleri etkin slota otomatik kayıt ister; duraklatma ve çıkış da kayıt alır. Aynı karedeki sinyaller tek deferred yazmada birleştirilir.

Snapshot'ın ana bölümleri:

| Bölüm | Saklanan durum |
|---|---|
| Kimlik | `match_id`, oyun sürümü, seed, mod, kurallar bütünü, maç adı ve tur süresi |
| GameManager | aktif/ilk oyuncu, tur/raund/faz, Enerji ve geçici Enerji, Merkez canları, mulligan, hamle hakları, kalan süre |
| Bölgeler | iki deste sırası, iki el, mezarlıklar, saha ve Merkez kartları, slot/koridor kimliği |
| Kart runtime | fiziksel ağ kimliği, sahip, mevcut/maksimum statlar, seviye/XP, trait ve durumlar, Beceri eki, hazır/tükenmiş ve hareket durumu |
| RNG | iki deste RNG'sinin seed+state değeri ve AI RNG state'i |
| Etki Kartları | iki teklif, seçimler, tur içi ledger, son tetik ve maç-geneli tetik sayacı |

Restore önce tüm el/saha/mezarlık fiziksel kimliklerini ve sahipliği doğrular. Yinelenen kimlik, bilinmeyen kart, geçersiz sahip veya deste sınırını aşan fiziksel kart sayısı kabul edilmez. Teklifler yeniden üretilmez; deste sırası ve RNG `state` değerleri doğrudan geri konur. Tur sayacı kayıtlı kalan süreden, sahne kurulum karelerini tüketmeden sürer.

Ana menüdeki **YÜKLE** düğmesi kayıt slotlarını ad, oyun modu, raund, tur ve tarih bilgileriyle listeler. Seçilen kayıt bozuk/eski/uyumsuzsa yeni maç başlatılmaz; kullanıcı geçerli yedekten kurtarabilir veya yalnızca o slotu silebilir. Kayıt bulunmadığında **YÜKLE** görünür kalır ancak devre dışıdır.

Çevrimiçi maçlarda bu yerel yuva kullanılmaz. Dedicated snapshot ve yeniden bağlanma güvenlik modeli için [MULTIPLAYER_SERVER.md](MULTIPLAYER_SERVER.md) belgesine bakın.

## Etki Kartı seçimi ve gizlilik

Etki Kartı eldeki Büyü/Beceri kartlarından ayrı, hedeflenemez maç-geneli pasiftir. Enerji, saldırı, zırh ve can taşımaz. On kartın tamamı her maçta açıktır ve eşit teklif olasılığına sahiptir; nadirlik yalnızca çerçeve/galeri sınıfıdır.

`EFFECT_SELECTION`, mulligan'dan önce gelir. Seed'lenmiş Etki RNG'si her oyuncuya kendi içinde benzersiz üç kart üretir. Teklifler bağımsızdır ve iki oyuncu aynı kartı seçebilir. Yerel hot-seat akışı el değiştirme perdesi kullanır; AI deste kompozisyonunu deterministik puanlar. Süre aşımında yalnızca o tekliften deterministik seçim yapılır. Çevrimiçinde üretim, doğrulama ve timeout yalnızca sunucudadır.

Sağ panelde oyuncunun seçimi ortak `EffectCard` template'inden açık gösterilir. Rakip slotu nötr arka yüz kullanır; kart adı, nadirlik, görsel, açıklama ve tetik ayrıntısı network perspektif snapshot'ına girmez. Bu gizlilik maç sonu ekranında da değişmez.

## Tetik sırası ve tur ledger'ı

Her oyuncunun ledger'ı yeni tur başında sıfırlanır; `match_trigger_count` sıfırlanmaz. Başarısız veya yasadışı hamle ledger tüketmez. Aynı resolver çağrısında bir pasif ikinci kez çalışamaz.

| Kart | Kesin çözüm noktası ve sınır |
|---|---|
| Yapı Ustaları | Yerleşke yasal olarak sahaya girdikten sonra o turdaki ilk Yerleşkeye mevcut+maksimum 2 Can. |
| Saha Hekimleri | Tur sonu etkilerinde bir kez; Merkez dışındaki en çok Can eksiği olan dost. Eşitlikte savaş alanının sabit slot dolaşımındaki ilk kart. |
| Kanat Manevrası | İlk yasal hareketin maliyet hesabında 0; koridor/hedef/faz doğrulaması değişmez. Başarılı hareketten sonra tüketilir. |
| Öncü Doktrini | İlk yasal Kahramanın maliyet hesabında -1, taban 1; başarılı oynama sonrası tüketilir. |
| Gizli Cephanelik | İlk yasal `SpecialPowerCard` maliyetinde -1, taban 1; başarılı çözüm sonrası tüketilir. |
| Koruyucu Yemin | Tur başlangıcında bir kez; Merkez dışındaki en yaralı korumasız dost, eşitlikte sabit slot sırası. `Korumalı 1` stacklenmez. |
| Kuşatma Planı | Çatışmada ilk uygun normal saldırının gerçek hedefi düşman Yerleşke/Merkez ise hasar hesabına +1. Muhafıza yönlenen saldırı tüketmez. |
| Dövme Ocağı | İlk başarılı Beceri normal etkisini çözdükten sonra geçerli hedefe mevcut+maksimum 1 Can. |
| İkmal Hattı | Turun ilk pozitif Enerji harcayan yasal hamlesi kontrol edilir. Son Enerji 0 ve elde boş yer varsa bir çekiş istenir; sonraki harcamalar kontrol edilmez. |
| Son Direniş | Rakibin turunda Merkeze gelen ilk pozitif hasar hesabında -1, taban 0; sonraki Merkez hasarları normaldir. |

Hasar sırası merkezi `EffectResolver.apply_damage` içindedir: yasal/gerçek hedef belirlenir, Kuşatma Planı yalnızca yönlenmemiş normal saldırıya eklenir, Son Direniş savunan Merkezde azaltır, ardından nihai hasar uygulanır. UI hiçbir statı veya Enerjiyi doğrudan değiştirmez.

## Doğrulama komutları

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/profile_persistence_sync_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/active_match_save_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/active_match_menu_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/save_slots_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/effect_cards_rules_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/effect_cards_ui_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/effect_card_balance_suite.gd
```

Daha geniş denge örneklemi için `TDM_EFFECT_BALANCE_MATCHES_PER_CARD=12` veya daha büyük bir değer verilebilir. Paket her kartın kazanma oranını, %95 Wilson aralığını, tetiklenme oranını, ortalama tetik sayısını ve deterministik sonuç imzasını JSON olarak üretir.
