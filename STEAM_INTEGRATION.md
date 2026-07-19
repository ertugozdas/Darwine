# Darwine Steam entegrasyonu

Darwine, Godot 4.7 ile uyumlu resmi GodotSteam GDExtension 4.20.1 paketini kullanır. Entegrasyon çevrimdışı oyunu ve mevcut UDP/dedicated sunucu akışını bozmadan şu yüzeyleri sağlar:

Upstream paket: [GodotSteam 4.20.1 GDExtension release](https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.20.1-gde). Lisans metni `addons/godotsteam/license.md` altında korunur.

- Steam başlatma, kullanıcı kimliği ve persona adı
- Steam Lobby arama, oda açma, katılma ve arkadaş daveti
- Steam Networking Messages üzerinden relay/NAT geçişli P2P taşıma
- Mevcut Godot RPC, kimlik doğrulama, deste doğrulama ve otoriter snapshot protokolü
- Steam başarımları ve INT istatistikleri
- Steam Cloud profil eşitlemesi ve önceki Cloud belgesinin yedeği
- Rich Presence ve `+connect_lobby <id>` ile davetten/başlatma parametresinden katılım
- Steam çalışmıyorsa çevrimdışı oyun ile kodlu UDP odalarına güvenli geri dönüş

## Dosya ve servis haritası

- `addons/godotsteam/`: Windows, Linux, macOS ve Android arm64 için resmi GDExtension ikilileri.
- `scripts/steam_manager.gd`: Steam yaşam döngüsü, Lobby, Cloud, başarımlar, istatistikler ve Rich Presence.
- `scripts/steam_p2p_peer.gd`: Steam Networking Messages'ı Godot `MultiplayerPeerExtension` sözleşmesine bağlayan taşıma.
- `scripts/steam_profile_sync_provider.gd`: Steam hesabına bağlı Cloud profil zarfı, deterministik birleştirme, yedek ve yazma-sonrası doğrulama.
- `scripts/network_manager.gd`: UDP/dedicated ve Steam P2P taşımalarını aynı oyun protokolünde buluşturur.
- `steam_appid.txt`: Yalnızca yerel geliştirme için App ID.

P2P odasında oda sahibi Godot peer `1`, katılan oyuncu peer `2` olur. Lobby yalnızca keşif ve üyelik sınırını belirler. Kimlik doğrulama, davet sırrı, deste payload'ı, RPC'ler ve maç snapshot'ları mevcut `NetworkManager` üzerinden yürür. Lobi dışındaki Steam kimliklerinden gelen paketler kabul edilmez; paket boyutu ve kuyrukları sınırlıdır.

## App ID

Projede geliştirme varsayılanı Valve Spacewar App ID `480` olarak tutulur:

- `project.godot`: `steam/initialization/app_data/app_id=480`
- `steam_appid.txt`: `480`

Steamworks uygulaması teslim edilmeden önce iki değer de gerçek Darwine App ID'siyle değiştirilmelidir. `steam_appid.txt`, uygulama Steam istemcisinden başlatıldığında gerekli değildir; production depot'una eklenmemelidir. Yerel editör/export testi için yürütülebilir dosyanın yanında tutulabilir.

## Steamworks başarımları

Steamworks > Stats & Achievements bölümünde API adları aşağıdaki gibi **birebir** açılmalıdır:

| API adı | Türkçe görünen ad | Açılma koşulu | İlerleme istatistiği |
|---|---|---|---|
| `DARWINE_ACH_FIRST_WIN` | İlk Sancak | İlk zafer | `DARWINE_STAT_WINS` / 1 |
| `DARWINE_ACH_10_MATCHES` | Tecrübeli Komutan | 10 maç | `DARWINE_STAT_MATCHES` / 10 |
| `DARWINE_ACH_100_HQ_DAMAGE` | Kuşatma İzi | Toplam 100 merkez hasarı | `DARWINE_STAT_HQ_DAMAGE` / 100 |
| `DARWINE_ACH_3_WIN_STREAK` | Demir Seri | En iyi seri 3 | `DARWINE_STAT_BEST_STREAK` / 3 |

Başarım ikonlarının kilitli ve açık halleri Steamworks'e yüklenmeli, tüm dillerde görünen ad/açıklamalar girilmeli ve değişiklikler Publish edilmelidir.

## Steamworks istatistikleri

Aşağıdaki değerlerin tamamı `INT` olmalı, varsayılan değerleri `0` ve minimumları `0` olarak tanımlanmalıdır:

| API adı | Oyun içi kaynak |
|---|---|
| `DARWINE_STAT_MATCHES` | Tamamlanan maç |
| `DARWINE_STAT_WINS` | Zafer |
| `DARWINE_STAT_ONLINE_MATCHES` | Çevrimiçi maç |
| `DARWINE_STAT_CARDS_PLAYED` | Oynanan kart |
| `DARWINE_STAT_HQ_DAMAGE` | Merkez hasarı |
| `DARWINE_STAT_BEST_STREAK` | En iyi zafer serisi |
| `DARWINE_STAT_DOMINION_WINS` | Hakimiyet zaferi |

GodotSteam 4.20 / Steamworks SDK 1.61+ güncel istatistikleri başlangıçta eşitler; proje ayrıca maç kaydı oluştuğunda `setStatInt`, `setAchievement` ve `storeStats` çağrılarını yapar.

## Steam Cloud

Steamworks > Cloud bölümünde Steam Auto-Cloud kullanılmadan Remote Storage kotası etkinleştirilmelidir. Proje şu dosyaları API ile yönetir:

- `darwine_profile_v1.json`: doğrulanmış güncel profil zarfı
- `darwine_profile_v1.backup.json`: yazmadan önceki okunabilir Cloud belgesi

Önerilen hesap başı kota en az 5 MB ve dosya sayısı en az 10'dur. Profil belgesi 2 MB sınırını aşarsa istemci yazmayı reddeder. Eşitleme; monoton sayaçları geriletmez, başarımları ve kozmetikleri birleştirir, benzersiz maç geçmişini korur, deste/ayar bölümlerinde en yeni zaman damgasını seçer ve yazdığı revizyonu tekrar okuyarak doğrular.

Steam Cloud istemci kontrollü bir hesap kopyasıdır; anti-cheat veya güvenilir rekabet sunucusu değildir. Rekabetçi sıralama ve ödül ekonomisi ileride doğrulanan dedicated/backend sonuçlarından beslenmelidir.

## Lobby, davet ve Rich Presence

Lobby metadata anahtarları `darwine_game`, protokol sürümü, uygulama sürümü, maç adı, mod, kart kapsamı, tur süresi, otomatik savaş izni, lobi durumu ve oturum sırrını taşır. Arama yalnızca uyumlu `darwine_game=darwine` ve protokol sürümünü listeler.

Arkadaş daveti oyun içindeki **STEAM P2P** sekmesinden Steam Overlay ile açılır. Overlay editörde/Vulkan koşullarında görünmeyebilir; Steam'e yüklenmiş export build üzerinde denenmelidir. Rich Presence bağlantı alanı `+connect_lobby <lobby_id>` üretir ve uygulama bu parametreyle açıldığında katılım isteğini menüye iletir.

Geçici P2P taşıma kesintilerinde aynı Steam Lobby üyeliği ve reconnect token ile oturum yeniden kurulur. Şu an host migration yoktur; oda sahibi Lobby'den ayrılırsa maç açık bir hata mesajıyla sona erer. Uzun ömürlü/rekabetçi oturumlar için mevcut UDP dedicated sunucusu bağımsız seçenek olarak korunur.

## Export ve Steam depot kontrol listesi

1. Gerçek App ID'yi `project.godot` içine yaz.
2. Yerel testte `steam_appid.txt` değerini aynı App ID yap; depot manifestinden bu dosyayı çıkar.
3. Normal Godot 4.7 export template'lerini kullan. GodotSteam'e özel module template'i kullanma.
4. Hedef platformun GodotSteam bağımlılıklarının export yanında bulunduğunu doğrula (`steam_api64`, ilgili GDExtension library ve platform runtime'ı).
5. Steamworks başarımlarını, istatistiklerini ve Cloud kotasını Publish et.
6. Build'i SteamPipe ile beta branch'e yükle ve Steam istemcisinden çalıştır.
7. İki farklı Steam hesabı ve iki makine/oturumla public/friends-only Lobby, Overlay daveti, relay P2P maç başlangıcı, yeniden bağlanma ve host ayrılmasını dene.
8. Bir maç tamamlayıp Steam Overlay'de başarım/istatistikleri; ikinci cihazda Cloud profilini doğrula.
9. Steam kapalıyken oyunun çevrimdışı açıldığını ve UDP kodlu odaların hâlâ çalıştığını doğrula.

## Yerel doğrulama

Steam istemcisi olmadan API yüzeyi, paket taşıması, güvenlik filtresi ve Cloud birleştirme testi:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/steam_integration_smoke.gd
```

Ana menüde UDP ve Steam sekmelerinin birlikte doğrulanması:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/main_menu_smoke.gd
```

Gerçek Lobby/Overlay/relay doğrulaması Steam istemcisi, yayınlanmış Steamworks yapılandırması ve iki yetkili hesap gerektirir.
