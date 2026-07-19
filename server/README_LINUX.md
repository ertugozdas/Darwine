# Darwine Dedicated Server — Ubuntu 24.04 x86_64

İlk kurulumda UDP portunu açın:

```bash
sudo ufw allow 7777/udp
```

Ardından sunucuyu tek komutla çalıştırın:

```bash
./darwine-server
```

Çalıştırıcı genel IPv4 adresini otomatik bulur ve konsola oyuncularla paylaşacağınız davet kodunu basar. İki oyuncu kodla katılınca maç otomatik başlar.

Farklı port veya elle IP vermek için:

```bash
PUBLIC_IP=203.0.113.10 PORT=7788 ./darwine-server
```

Hakimiyet odası açmak için ruleset'i ortam değişkeniyle seçin:

```bash
RULESET=dominion ./darwine-server
```

Varsayılan değer `siege` (Kuşatma) olarak kalır. Ruleset oda açılırken sabitlenir; yeniden bağlanma ve rövanşlarda korunur.

## Aktif maç kurtarma

Oyuncu bağlantısı kesilirse maç ve tur sayacı en fazla 90 saniye duraklatılır. Aynı davet/reconnect kimliğiyle dönen oyuncuya sunucunun tam otoriter snapshot'ı gönderilir. Süre dolduğunda bağlı oyuncu hükmen kazanır; iki oyuncu da dönmezse maç iptal edilir.

Dedicated süreç aktif maçı Godot kullanıcı veri dizinindeki `darwine_online_match_<port>.json` dosyasına atomik yazar ve iki yedek tutar. Sunucu yeniden başladığında aynı `PORT`, `PUBLIC_IP` ve varsa aynı `SECRET` ile bu kaydı doğrulayıp maçı kurtarır. Systemd veya container kurulumunda süreç kullanıcısının Godot `user://` dizinini kalıcı volume üzerinde tutun; geçici HOME kullanmayın.

Sunucunun kurtarmayı algıladığını logdaki `DARWINE_SERVER_MATCH_RESTORED` ve savaş alanına uyguladığını `DARWINE_SERVER_SNAPSHOT_APPLIED` satırlarından izleyebilirsiniz.

Bulut sağlayıcınızın güvenlik grubunda veya yönlendiricinizde seçtiğiniz UDP portunu da açmanız gerekir. TCP kuralı yeterli değildir.
