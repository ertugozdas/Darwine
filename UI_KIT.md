# Darwine Dark Fantasy UI Kit

Bu belge, oyunun menü, HUD, modal ve yardımcı ekranlarında kullanılacak tek görsel dili tanımlar. Çalışan kaynak `scripts/dark_fantasy_ui.gd`; bu dosya tasarım kararlarının kısa referansıdır.

## Tasarım ilkesi

Arayüz, kuşatma masasının parçası gibi görünür: kararmış dövme demir, aşınmış deri, is ve az miktarda antik pirinç. Yüzeyler gerçek malzeme hissi taşır; parlak plastik, cam efekti, neon ve modern uygulama kartları kullanılmaz. Oyun alanının merkezi açık bırakılır; uzun açıklamalar yalnızca menü ve modal yüzeylerde görünür.

## Renk tokenları

| Token | Hex | Kullanım |
| --- | --- | --- |
| `VOID` | `#070708` | En koyu arka plan ve perde |
| `OBSIDIAN` | `#0C0B0B` | Ana panel iç yüzeyi |
| `IRON` | `#181716` | İkincil yüzey ve kontrol zemini |
| `BRASS_DARK` | `#6E5029` | Pasif sınır ve ayraç |
| `BRASS` | `#B8853D` | Birincil vurgu ve odak |
| `BRASS_BRIGHT` | `#EDBF63` | Hover, başlık ve önemli değer |
| `PARCHMENT` | `#EBDEC2` | Ana metin |
| `TEXT_MUTED` | `#A39E94` | İkincil metin |
| `BLOOD` | `#9C332B` | Tehlike, silme ve maçı terk etme |
| `FROST` | `#4F8CB3` | Bilgi ve Oyuncu 2 vurgusu |
| `MOSS` | `#4F7A54` | Başarı ve geçerli eylem |

Renk oranı: yaklaşık `%70` siyah/demir, `%20` deri ve nötr ton, `%8` pirinç, `%2` durum rengi. Pirinç geniş dolgu olarak değil, kenar, tipografi ve odak vurgusu olarak kullanılır.

## Tipografi

- Gösterim ve buton: **Cinzel**. Büyük başlıklar, bölüm adları, faz adı ve buton metinleri.
- Gövde ve veri: **Alegreya Sans**. Açıklama, ayar satırı, ipucu, kart ayrıntısı ve sayısal olmayan uzun metinler.
- Başlıklar tercihen büyük harf; gövde metni normal cümle düzeninde yazılır.
- 1280×720 tabanı: ana başlık `56–72`, modal başlık `24–32`, buton `15–18`, gövde `14–17`, yardımcı metin `11–13` px.
- Okunabilirlik için metin başına en fazla `2–3 px` koyu kontur; uzun gövde metninde kontur kullanılmaz.

Fontlar `fonts/` altında projeye gömülüdür. Her iki aile de kendi `fonts/licenses/` OFL lisansıyla tutulur.

## Malzeme ve bileşenler

### Birincil buton

- `images/ui/kit/button_forged.png` dokusunu 9-slice olarak kullanır.
- Normal: nötr kararmış demir; pirinç yalnızca çerçevede okunur.
- Hover: sıcaklık ve kontrast artar; kontrol büyümez.
- Basılı: yüzey koyulaşır ve metin `2 px` aşağı oturur.
- Odak: dokuyu kapatmayan açık pirinç kontur.
- Devre dışı: gri, düşük kontrast; yine de metin okunur.
- Tehlikeli eylemde aynı malzeme korunur, yalnızca `BLOOD` vurgusu kullanılır.

### Panel ve modal

- `images/ui/kit/panel_forged.png` 9-slice yüzeyidir.
- Süs yalnızca dış kenarlarda kalır; dinamik metnin bulunduğu merkez sakin ve koyudur.
- Ana menü ve modal panellerde `24–34 px`, kompakt HUD panellerinde `12–18 px` iç boşluk kullanılır.
- Tam ekran karartma yaklaşık `%82–88` opaklıktadır; modal açıkken oyun girdisi durdurulur.

### HUD

- Kalıcı üst HUD; tur, aşama, Enerji, bizim Merkez canı ve rakip Merkez canını tek bir dövme metal şeritte gösterir.
- Merkez canı kartların üstünde tekrarlanmaz; sağlık bilgisinin tek kaynağı üst HUD'dır.
- Sağ sütunun üstü rakip deste sayısına ayrılmaz; kart önizlemesi eylem kontrollerine kadar kesintisiz uzanır.
- Merkez grid ve alt-orta oyun alanı boş tutulur.
- Oyuncu renkleri yüzeyi değiştirmez; sadece ince sınır, rota ve durum vurgusunda kullanılır.

### Savaş durumu ve hareket

- Seçili saldırgan yosun/altın, yasal hedef kan kırmızısı konturla ve yavaş nabızla ayrışır.
- Saldırı önce hedefe uzanan iz ile okunur, ardından darbe çözülür; normal oyunda telegraph ve darbe toplamı yaklaşık `0.9–1.2 sn` sürer.
- Kart sürükleme sırasında kart yükselir, pirinç kontur ve gölge kazanır; geçersiz hedefe bırakıldığında aynı görsel dille geri döner.
- Seviye, Hazır/Tükenmiş ve bağlı Beceri bilgileri kart resmini kapatan geniş şeritler yerine küçük kenar rozetlerinde gösterilir.

### Aralık ve şekil

- Aralık ölçeği: `4 / 8 / 12 / 16 / 24 / 32`.
- Buton yüksekliği: kompakt `40–44`, standart `52–56`, ana menü `60–64`.
- Köşeler yuvarlak uygulama kartı gibi değil, `2–6 px` arası hafif dövülmüş plaka hissindedir.
- Animasyon: hover `100–140 ms`, modal giriş `160–220 ms`, kritik faz değişimi `250–350 ms`. Sürekli dekoratif hareket kullanılmaz.

## Uygulama kuralı

Yeni bir ekran kendi rastgele renklerini ve buton stilini üretmemelidir. Kök `Control` üzerinde `DarkFantasyUI.create_theme()` kullanılmalı; özel butonlar `DarkFantasyUI.style_button()`, başlıklar `DarkFantasyUI.style_title()`, paneller `DarkFantasyUI.panel_style()` üzerinden kurulmalıdır. Yeni bir durum rengi gerekiyorsa önce bu kitte token olarak tanımlanır.
