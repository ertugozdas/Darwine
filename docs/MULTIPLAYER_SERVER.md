# Darwine Multiplayer ve Dedicated Sunucu

Darwine artık iki oyunculu, sunucu-otoriteli ENet multiplayer akışına sahiptir. Oyuncu sunucu adresi veya port yazmaz; sunucunun ürettiği 20 karakterlik davet kodunu ana menüde **Çevrimiçi Oyna** ekranına yapıştırır. Kod genel IPv4 adresini, UDP portunu, protokol sürümünü, oturum anahtarını ve yazım hatası kontrolünü içerir.

İstemci yalnızca niyet edilen hamleyi yollar. Kart sahipliği, sıra/faz, hedef, Enerji, Etki Kartı teklifi ve sonuç sunucuda doğrulanır. `load`, `snapshot`, `restore`, `set_stat` ve `set_stats` istekleri istemci kaynağından koşulsuz reddedilir.

## Linux paketini üretme

Proje kökünde tek komut çalıştırın:

```bash
./server/build_linux_server.sh
```

Çıktı:

```text
dist/darwine-linux-server-ubuntu24-x86_64.tar.gz
```

Paket resmi Godot 4.7 Linux x86_64 çalıştırıcısını, dedicated PCK dosyasını ve başlatma betiğini içerir. Ubuntu sunucuda Godot, grafik arayüz veya export template kurmanız gerekmez.

## Ubuntu 24.04 üzerinde çalıştırma

Arşivi sunucuya kopyaladıktan sonra:

```bash
tar -xzf darwine-linux-server-ubuntu24-x86_64.tar.gz
cd darwine-linux-server
sudo ufw allow 7777/udp
./darwine-server
```

Sonraki çalıştırmalar tek komuttur:

```bash
./darwine-server
```

Konsolda şuna benzer bir satır görünür:

```text
DARWINE_INVITE_CODE=075G0-W9A3S-GH4D2-PF2TG
```

Bu kodu iki oyuncuya gönderin. İki oyuncu katılınca sunucu maçı otomatik başlatır.

## Kopma, yeniden bağlanma ve sunucu yeniden başlatma

- Bir oyuncu kopunca otoriter tur sayacı durur ve **90 saniyelik** yeniden bağlanma penceresi açılır. Bu sırada diğer istemciden yeni hamle kabul edilmez.
- Aynı oyuncu kimliği ve yeniden bağlanma anahtarıyla dönen istemciye tam otoriter snapshot gönderilir; iki oyuncu hazır olunca sayaç kaldığı yerden sürer.
- Süre dolduğunda bağlı kalan oyuncu hükmen kazanır. İki oyuncu da bağlı değilse maç iptal edilir; `game_over` üretilmediği için rekabetçi profile sonuç yazılmaz.
- Dedicated süreç her otoriter revizyonda `user://darwine_online_match_<port>.json` dosyasını atomik olarak yeniler ve iki yedek tutar. İçerik; `match_id`, 48 karakterlik oturum anahtarı, seed, revizyon, oyuncu/reconnect kimlikleri, 30 kartlık desteler, tam aktif maç snapshot'ı ve en fazla 96 olaylık günlük taşır.
- Süreç yeniden açıldığında port, genel IP ve varsa `SECRET` kalıcı kayıtla uyuşuyorsa snapshot yüklenir. İki oyuncu başlangıçta bağlantısız kabul edilir, yeni 90 saniyelik pencere açılır ve savaş alanı tam snapshot'tan kurulur.
- Normal maç sonu veya iki oyuncunun maçı terk etmesi kalıcı aktif maç ailesini siler.

Restore sırasında sunucu kayıt şemasını, iki oyuncuyu, reconnect anahtarlarını, deste boyutlarını, seed'i ve snapshot iç kimliğini doğrular. İstemci tarafı da gelen her durumu `match_id + session_key + player_id + perspective_player_id` ile eşleştirir ve yalnızca son kabul edilen revizyondan büyük revizyonu uygular. Bu nedenle eski, başka perspektife ait veya sahte snapshot görüntüleme önbelleğine dahi uygulanmaz.

Sunucu veri dizini süreç kullanıcısına aittir. Systemd veya container kullanırken Godot `user://` dizinini kalıcı bir volume üzerinde tutun; bu dizin silinirse süreç yeniden başlatma kurtarması mümkün olmaz.

### Port ve IP ayarları

Varsayılan port `7777/udp`'dir. Farklı port veya elle genel IPv4 vermek için:

```bash
PUBLIC_IP=203.0.113.10 PORT=7788 ./darwine-server
```

Kalıcı bir davet oturum anahtarı isterseniz `1` ile `2147483647` arasında bir değer kullanabilirsiniz:

```bash
SECRET=123456789 ./darwine-server
```

`SECRET` verilmezse her sunucu açılışında yeni bir kod üretilir. Genel IP otomatik tespit edilemezse `PUBLIC_IP` zorunludur.

Bulut sağlayıcısında UDP portunu ayrıca security group/firewall üzerinden açın. Ev veya ofis ağında aynı UDP portunu yönlendiriciden sunucuya port-forward etmeniz gerekir.

## Geliştirici doğrulaması

Davet kodu testi:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/invite_code_smoke.gd
```

Gerçek bir dedicated sunucu ve iki headless istemciyle uçtan uca test:

```bash
./server/smoke_test.sh
```

Test, iki istemcinin kimlik doğrulamasını, lobi eşleşmesini, savaş alanı senkronizasyonunu ve iki oyuncunun sunucuya mulligan hamlesi göndermesini doğrular.

Kopma/geri dönüş, rövanş ve kurallar bütünü akışı:

```bash
./server/online_flow_smoke_test.sh
```

Gerçek dedicated süreci öldürüp aynı port ve veri diziniyle yeniden başlatan kurtarma testi:

```bash
./server/restart_recovery_smoke_test.sh
```

Bu test başarıda `SERVER_RESTART_RECOVERY_SMOKE_OK` üretir; iki istemcinin aynı `match_id`, oturum ve artan revizyonla geri döndüğünü doğrular.

Üretilmiş dedicated PCK dosyasını aynı akışla doğrulamak için:

```bash
SERVER_PACK=dist/darwine-linux-server/darwine-server.pck ./server/smoke_test.sh
```
