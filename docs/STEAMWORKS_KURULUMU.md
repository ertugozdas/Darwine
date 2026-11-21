# Darwine Steamworks yayın kurulumu

Kod tarafında Steam istemcisi, callback döngüsü, Shift+Tab Overlay, arkadaş daveti,
davetten/`+connect_lobby` ile katılma, Steam P2P lobi, Rich Presence, Cloud profil,
istatistik ve başarımlar bağlıdır. Gerçek başarımlar ile Rich Presence metinlerinin
görünmesi için aşağıdaki tanımlar Darwine'ın kendi Steamworks App ID'sinde oluşturulup
yayınlanmalıdır.

## 1. App ID ve çalıştırma

1. `project.godot` içindeki `steam/initialization/app_data/app_id` değerini Darwine'ın
   gerçek App ID'siyle değiştir.
2. Geliştirme ZIP'indeki `steam_appid.txt` yalnızca Steam dışından doğrudan EXE testi
   içindir. Steam depot'una yüklenen üretim build'inden bu dosyayı çıkar; App ID'yi
   Steam istemcisi sağlar.
3. Steamworks uygulama ayarlarında Steam Overlay'i etkinleştir ve değişikliği yayınla.
4. Launch Option, `Darwine.exe` dosyasını Windows executable olarak çalıştırmalıdır.

App ID `480`, Valve'ın Spacewar test uygulamasıdır. Lobi, arkadaş daveti ve Overlay
geliştirme testinde kullanılabilir; `DARWINE_*` API adları Spacewar backend'inde
tanımlı olmadığı için Darwine başarımları App ID 480'de açılamaz.

## 2. İstatistik tanımları

Steamworks > Stats & Achievements bölümünde aşağıdaki istatistikleri `INT`, varsayılan
`0`, istemci tarafından yazılabilir ve artan değerler olarak oluştur:

| API adı | Anlamı |
| --- | --- |
| `DARWINE_STAT_MATCHES` | Tamamlanan toplam maç |
| `DARWINE_STAT_WINS` | Toplam zafer |
| `DARWINE_STAT_ONLINE_MATCHES` | Tamamlanan çevrimiçi maç |
| `DARWINE_STAT_CARDS_PLAYED` | Oynanan toplam kart |
| `DARWINE_STAT_HQ_DAMAGE` | Merkezlere verilen toplam hasar |
| `DARWINE_STAT_BEST_STREAK` | En iyi zafer serisi |
| `DARWINE_STAT_DOMINION_WINS` | Hakimiyet zaferleri |

## 3. Başarım tanımları

| API adı | Türkçe ad | Koşul / ilerleme |
| --- | --- | --- |
| `DARWINE_ACH_FIRST_WIN` | İlk Sancak | İlk zafer, `DARWINE_STAT_WINS` 1/1 |
| `DARWINE_ACH_10_MATCHES` | Tecrübeli Komutan | `DARWINE_STAT_MATCHES` 10/10 |
| `DARWINE_ACH_100_HQ_DAMAGE` | Kuşatma İzi | `DARWINE_STAT_HQ_DAMAGE` 100/100 |
| `DARWINE_ACH_3_WIN_STREAK` | Demir Seri | `DARWINE_STAT_BEST_STREAK` 3/3 |

Her başarım için kilitli/açık ikonları yükle. Tanımları kaydetmek yetmez; Steamworks'te
`Publish` adımını tamamla. Kod, Steam istatistikleri yüklendikten sonra monotonik en
büyük değeri korur, ilerleme bildirimini gönderir, başarımı açar ve `StoreStats`
çağrısını yapar.

## 4. Enhanced Rich Presence

`steam_rich_presence_english.vdf` ve `steam_rich_presence_turkish.vdf` dosyalarındaki
token'ları Steamworks Rich Presence Localization bölümüne yükleyip yayınla. Kod şu
durumları gönderir:

- ana menü;
- katılınabilir Steam lobisi (`connect=+connect_lobby <lobby_id>`);
- oyun modu ve maç adıyla aktif maç;
- aynı lobideki arkadaşları gruplayan `steam_player_group` bilgisi.

## 5. Steam Cloud

Remote Storage/Steam Cloud'u etkinleştir. Kullanıcı başına en az 5 MB ve 10 dosya
önerilir. Darwine şu dosyaları kullanır:

- `darwine_profile_v1.json`
- `darwine_profile_v1.backup.json`

## 6. İki hesapla kabul testi

1. İki farklı Steam hesabına uygulama veya Playtest erişimi ver.
2. İki bilgisayarda aynı Steam branch build'ini çalıştır.
3. Host: `Çevrimiçi > Steam P2P > Steam Odası Aç > Arkadaş Davet Et`.
4. Diğer hesap Steam davetini kabul etsin. Oyun kapalıysa Steam oyunu
   `+connect_lobby` ile açmalı; açıksa doğrudan lobiye geçmelidir.
5. Her iki tarafta varsayılan Shift+Tab ile Overlay'i ve arkadaş listesini doğrula.
   Kısayol kullanıcı tarafından değiştirilebildiği için Steam ayarındaki gerçek
   Overlay kısayolu esas alınır.
6. Maçı tamamla; Steam istatistiklerini, başarım bildirimini, Rich Presence'i ve
   Cloud profilini iki hesapta kontrol et.

Overlay oyunun başında birkaç saniye `hazırlanıyor` görünebilir. Sürekli kapalıysa
Steam istemcisindeki oyun içi Overlay ayarını ve Steamworks uygulama Overlay ayarının
yayınlanmış olduğunu kontrol et.
