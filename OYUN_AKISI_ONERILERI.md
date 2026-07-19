# Kart Oyunu İçin 5 Farklı Oyun Akışı Önerisi

Bu belge, aynı kart türlerini ve ana hedefi kullanan ancak farklı stratejik deneyimler sunan beş ayrı oyun modeli önerir.

## Tüm Modellerde Sabit Kurallar

- İki oyuncunun da birer **Merkez Binası** bulunur.
- Oyunun amacı rakibin Merkez Binası'nın canını `0`a indirmektir.
- Her destede dört temel kart türü yer alır:
  - **Kahraman:** Savaş alanında kalan, hareket eden ve saldıran birlik.
  - **Yapı:** Yerleştirildiği bölgede kalan; savunma, üretim veya destek sağlayan kart.
  - **Beceri:** Bir Kahramana veya uygun bir Yapıya takılan ya da onun özel eylemini tetikleyen kart.
  - **Büyü:** Kullanıldığı anda etkisini gösteren, çoğunlukla tek kullanımlık kart.
- Kahramanlar ve Yapılar oyun sırasında yükseltilebilir.
- Bir kart en fazla üç seviyeye sahiptir: **Seviye 1**, **Seviye 2** ve **Seviye 3**.
- Seviye yükseltmek yalnızca sayısal güç artışı vermemeli; mümkün olduğunca oyuncuya iki farklı geliştirme dalından birini seçtirmelidir.

### Önerilen Ortak Başlangıç Değerleri

| Kural | Başlangıç değeri |
|---|---:|
| Merkez Binası canı | 30 |
| Deste boyutu | 30 kart |
| Başlangıç eli | 5 kart |
| Tur başına kart çekme | 1 kart |
| Elde tutulabilecek kart | 8 kart |
| Hedef maç süresi | 15–25 dakika |

Bu değerler ilk prototip içindir; oyun testlerinden sonra değiştirilmelidir.

---

## 1. Üç Koridorlu Kuşatma

### Ana fikir

Savaş alanı üç koridordan oluşur. Oyuncular Kahraman ve Yapılarını bu koridorlara yerleştirir. Bir koridorda rakip savunması kalmadığında o koridordaki Kahramanlar Merkez Binasına saldırabilir.

Bu model, anlaşılması en kolay ve klasik kart savaşı hissine en yakın seçenektir.

> Bu modelin kesinleştirilmiş kuralları ve geliştirme planı için [Üç Koridorlu Kuşatma: Oyun Tasarımı ve Geliştirme Yol Haritası](./UC_KORIDORLU_KUSATMA_TASARIMI_VE_YOL_HARITASI.md) belgesine bakın.

### Savaş alanı

- **Sol, Orta ve Sağ** olmak üzere üç koridor vardır.
- Her koridorda her oyuncu için iki Kahraman ve bir Yapı alanı bulunur.
- Merkez Binası bütün koridorların arkasındadır.
- Yapılar koridor değiştiremez; Kahramanlar belirli bir bedel ödeyerek komşu koridora geçebilir.

### Tur akışı

1. **Hazırlık:** Bir kart çekilir ve oyuncunun enerjisi yenilenir.
2. **Yerleştirme:** Kahraman ve Yapı kartları boş alanlara oynanır.
3. **Geliştirme:** Uygun Kahraman veya Yapılar yükseltilir; Beceri kartları takılır.
4. **Eylem:** Kahramanlar hareket eder veya saldırır.
5. **Büyü:** Oyuncu, savaşın sonucunu değiştirmek için Büyü kullanabilir.
6. **Tur sonu:** Süreli etkiler azalır ve sıra rakibe geçer.

### Kaynak sistemi

- Oyuncu ilk turda `3 Enerji` ile başlar.
- Azami enerji her tur `1` artar ve `10`da durur.
- Kart oynamak, koridor değiştirmek ve bazı özel saldırılar enerji harcar.

### Kartların rolü

- **Kahraman:** Koridoru savunur, rakip kartlarla savaşır ve yol açıldığında Merkez Binasına saldırır.
- **Yapı:** Koridoru korur, Kahraman üretir veya yakındaki kartlara destek verir.
- **Beceri:** Bir karta kalıcı özellik kazandırır; örneğin menzilli saldırı, karşı saldırı veya kalkan.
- **Büyü:** Bir veya birden fazla koridora anlık etki eder; örneğin hasar, iyileştirme, dondurma veya yer değiştirme.

### Yükseltme sistemi

Bir Kahraman, rakip bir kartı yok ettiğinde veya bir turun tamamında hayatta kaldığında **Tecrübe** kazanır. Yapılar ise görevlerini yerine getirerek Tecrübe kazanır; örneğin hasar engellemek veya enerji üretmek.

- Seviye 2 için `2 Tecrübe`
- Seviye 3 için `4 ilave Tecrübe`
- Her yükseltmede iki seçenek sunulur. Örneğin:
  - **Şövalye:** Muhafız dalında zırh kazanır veya Düellocu dalında saldırı kazanır.
  - **Okçu Kulesi:** Seri Atış dalında iki hedefe vurur veya Keskin Atış dalında daha uzağa ve daha güçlü vurur.

### Merkez Binasına saldırı

Bir Kahraman yalnızca kendi koridorunda rakip Kahraman veya koruyucu Yapı kalmadığında Merkez Binasına saldırabilir. Böylece önce cepheyi kazanmak gerekir.

### Örnek oyun akışı

Oyuncu Orta koridora bir Şövalye, arkasına da Şifacı Yapı koyar. Rakip Orta koridoru güçlendirince oyuncu Şövalyeyi savunma yönünde yükseltir, Sağ koridorda daha hızlı bir saldırı başlatır ve bir Büyü ile rakip savunmayı o koridordan uzaklaştırır. Sağ koridor açılınca Kahraman Merkez Binasına hasar vermeye başlar.

### Güçlü yanı ve tasarım riski

- **Güçlü yanı:** Kuralları görsel olarak kolay anlatılır ve ilk prototipe uygundur.
- **Risk:** Bir koridorda erken üstünlük kuran oyuncu maçı fazla kolay büyütebilir. Koridor değiştirme ve savunma amaçlı ucuz Büyüler bu etkiyi dengelemelidir.

---

## 2. Bölge Kontrolü ve İkmal Hatları

### Ana fikir

Oyuncular yalnızca rakibe saldırmaz; haritadaki kaynak bölgelerini ele geçirerek bir **ikmal hattı** kurar. Merkez Binasına ulaşmak için rakibin bölgelerinden geçmek gerekir.

Bu model konumlandırma, ekonomi ve uzun vadeli planlamayı öne çıkarır.

### Savaş alanı

- İki Merkez Binası arasında birbirine bağlı yedi bölge bulunur.
- Bölgelerin üçü kaynak noktası, ikisi savunma noktası, ikisi tarafsız geçittir.
- Bir bölgede en fazla iki Kahraman ve bir Yapı bulunabilir.
- Rakip Merkez Binasına giden kesintisiz bir kontrol zinciri, **İkmal Hattı** sayılır.

### Tur akışı

1. **Gelir:** Kontrol edilen kaynak bölgelerinden Altın ve Mana alınır.
2. **Kart çekme:** Bir kart çekilir.
3. **İnşa ve çağırma:** Yapılar kurulur, Kahramanlar Merkez Binasında veya uygun ileri karakollarda oyuna girer.
4. **Hareket:** Her Kahraman komşu bir bölgeye hareket edebilir.
5. **Çatışma:** Aynı bölgede rakip kartlar varsa savaş çözülür.
6. **Kontrol:** Boşaltılan bölgelerin sahipliği ve ikmal hatları yeniden hesaplanır.
7. **Yükseltme:** Kaynak harcanarak uygun kartlar geliştirilir.

### Kaynak sistemi

- **Altın:** Kahraman, Yapı ve yükseltmeler için kullanılır.
- **Mana:** Beceri ve Büyüler için kullanılır.
- Kaynak bölgeleri elde tutmak daha güçlü kartlara erişimi hızlandırır.
- İkmal hattından kopan bir Kahraman iyileştirilemez ve yükseltilemez.

### Kartların rolü

- **Kahraman:** Bölgeler arasında ilerler ve bölge kontrol eder.
- **Yapı:** Bulunduğu bölgeyi güçlendirir; kale, maden, mana kuyusu veya ileri karakol olabilir.
- **Beceri:** Keşif, pusu, hızlı hareket veya kuşatma gibi harita etkileşimleri kazandırır.
- **Büyü:** Bir bölgeyi veya bağlantıyı geçici olarak değiştirir; örneğin sis, deprem ya da ışınlanma.

### Yükseltme sistemi

Kahraman ve Yapılar, kontrol edilen kaynak bölgelerinde Altın harcanarak yükseltilir. İleri bölgede yükseltme yapmak daha pahalıdır; bu nedenle oyuncu güvenli gelişim ile hızlı baskı arasında karar verir.

Örnek Yapı gelişimi:

- **İleri Karakol Seviye 1:** Kahramanların burada oyuna girmesini sağlar.
- **Kale dalı:** Daha fazla can ve bölge savunması verir.
- **Lojistik dalı:** Yakındaki Kahramanların yükseltme maliyetini azaltır.

### Merkez Binasına saldırı

Bir oyuncu, kendi Merkez Binasından rakibin Merkez Binasına kadar kesintisiz bir İkmal Hattı kurduğunda son bölgedeki Kahramanlarıyla saldırabilir. Rakip hattın ortasındaki bir bölgeyi ele geçirirse saldırı yolu kesilir.

### Örnek oyun akışı

Oyuncu merkezdeki Mana Kuyusunu alır, buraya bir İleri Karakol kurar ve Kahramanlarını bu noktadan besler. Rakip doğrudan ilerlerken oyuncu bir geçidi ele geçirip rakibin ikmalini keser. Kaynaksız kalan rakip birlikler zayıflarken oyuncu karşı hatta ilerleyerek Merkez Binasına ulaşır.

### Güçlü yanı ve tasarım riski

- **Güçlü yanı:** Her maçta farklı stratejik rotalar ve geri dönüş fırsatları oluşturur.
- **Risk:** Bölge ve bağlantı kuralları ilk oyunda karmaşık gelebilir. Harita küçük tutulmalı ve ikmal hattı ekranda açıkça gösterilmelidir.

---

## 3. Gizli Emirler ve Eşzamanlı Çatışma

### Ana fikir

İki oyuncu da hamlelerini aynı anda, gizli biçimde planlar. Emirler birlikte açılır ve öncelik kurallarına göre çözülür. Başarı, rakibin niyetini tahmin etmeye dayanır.

Bu model blöf, karşı hamle ve kısa ama yoğun turlar sunar.

### Savaş alanı

- Her oyuncunun önünde üç mevzi vardır: **Saldırı**, **Destek** ve **Savunma**.
- Kahramanlar mevziler arasında hareket edebilir.
- Yapılar bir mevziye kurulur ve genellikle yer değiştiremez.
- Her oyuncunun tur başına kullanabildiği üç Emir taşı bulunur.

### Tur akışı

1. **Kart çekme:** İki oyuncu da aynı anda bir kart çeker.
2. **Planlama:** Oyuncular sırayla oynamak yerine üç gizli Emir hazırlar.
3. **Açığa çıkarma:** İki tarafın Emirleri aynı anda gösterilir.
4. **Çözüm:** Emirler sırasıyla `Hızlı`, `Normal` ve `Ağır` önceliğinde uygulanır.
5. **Çatışma:** Aynı mevzide karşılaşan kartlar savaşır.
6. **Bakım:** Kaynaklar, bekleme süreleri ve yükseltmeler güncellenir.

### Emir türleri

- **Oyna:** Elden bir Kahraman veya Yapı çıkar.
- **Saldır:** Bir Kahramanla hedefe saldır.
- **Hareket:** Kahramanı başka mevziye taşı.
- **Geliştir:** Bir Kahraman veya Yapıyı yükselt.
- **Beceri/Büyü:** İlgili kartı kullan.
- **Savun:** Bir sonraki hasarı azalt ve tepki hakkı kazan.

### Kaynak sistemi

- Her oyuncu tur başında `5 Odak` kazanır.
- Emir hazırlamak taş harcar; kartların Odak bedeli ayrıca ödenir.
- Kullanılmayan Odak bir sonraki tura aktarılmaz.
- Güçlü hamleler yavaş öncelikte, savunma ve küçük Beceri kartları hızlı öncelikte çözülür.

### Kartların rolü

- **Kahraman:** Emir verildiğinde hareket eder, saldırır veya özel yeteneğini kullanır.
- **Yapı:** Emir ekonomisini, savunmayı veya kart çekmeyi güçlendirir.
- **Beceri:** Bir Emri değiştirir; hızlandırma, hedef değiştirme veya saldırıdan sonra geri çekilme sağlayabilir.
- **Büyü:** Planlar açıldıktan sonra kullanılabilen sınırlı sayıdaki tepki kartlarını içerir.

### Yükseltme sistemi

Bir kartı yükseltmek için planlama aşamasında bir **Geliştir Emri** ayrılmalıdır. Yükseltme bu nedenle yalnızca kaynak değil, turdaki eylemlerden birini de harcar.

- Kahramanlar saldırı, hareket veya özel yetenek dalında gelişebilir.
- Yapılar dayanıklılık, üretim veya tepki dalında gelişebilir.
- Seviye 3 kartlar bir ek Emir kazanmaz; var olan Emirleri daha etkili hâle getirir. Böylece sınırsız hamle zincirleri önlenir.

### Merkez Binasına saldırı

Saldırı mevzisindeki bir Kahraman, karşısında rakip Kahraman veya savunma Yapısı yoksa **Saldır Emri** ile Merkez Binasını hedefleyebilir. Rakip aynı turda oraya bir savunma yerleştirirse saldırı bu yeni hedefe çarpar.

### Örnek oyun akışı

Oyuncu rakibin savunmaya geçeceğini düşünerek ağır bir saldırı yerine Kahramanını Destek mevzisine taşımayı ve Yapısını yükseltmeyi planlar. Rakip gerçekten Savun Emri harcadığı için boşa tempo kaybeder. Sonraki tur oyuncu hızlı bir Beceriyle mevzi değiştirir ve beklenmeyen yönden Merkez Binasına vurur.

### Güçlü yanı ve tasarım riski

- **Güçlü yanı:** Bekleme süresini azaltır ve her turda güçlü bir zihin oyunu yaratır.
- **Risk:** Çözüm sırası yeterince görünür değilse sonuçlar rastgele hissedilebilir. Oyun, emirleri gerçekleşmeden önce zaman çizelgesinde göstermelidir.

---

## 4. Gündüz Hazırlığı, Gece Kuşatması

### Ana fikir

Her raund iki farklı evreden oluşur. **Gündüz** oyuncular kart oynar, yapı kurar ve yükseltme yapar. **Gece** ordular otomatik olarak ilerler ve savaşır. Oyuncular gece sırasında yalnızca sınırlı Beceri ve Büyülerle müdahale eder.

Bu model deste kurma kararları ile otomatik savaşın izlenebilir heyecanını birleştirir.

### Savaş alanı

- İki Merkez Binası arasında beş karelik tek bir savaş yolu vardır.
- Yolun iki yanında oyunculara ait Yapı alanları bulunur.
- Kahramanlar gündüz sıraya dizilir; gece başlayınca hız değerlerine göre ilerler.
- Her gece en fazla belirli sayıda Kahraman savaşa çıkabilir.

### Raund akışı

1. **Şafak:** İki oyuncu ikişer kart çeker ve gelir kazanır.
2. **Gündüz:** Oyuncular dönüşümlü olarak toplam üç hazırlık eylemi yapar.
3. **Dizilim:** Kahramanların gece yürüyeceği sıra belirlenir.
4. **Gece başlangıcı:** Kahramanlar otomatik olarak ilerlemeye başlar.
5. **Çatışma:** Karşılaşan Kahramanlar hız ve menzil değerlerine göre savaşır.
6. **Müdahale:** Her oyuncu gece boyunca en fazla iki Beceri veya Büyü kullanabilir.
7. **Gece sonu:** Hayatta kalanlar bulundukları karede kamp kurar; yeni raund başlar.

### Kaynak sistemi

- Her şafakta temel Altın geliri alınır.
- Hayatta kalan Kahramanlar bir sonraki gündüz için **Moral** üretir.
- Moral yalnızca yükseltmelerde ve güçlü Beceri kartlarında kullanılır.
- Kaybedilen Kahramanlar rakibe az miktarda Moral verir; böylece her saldırı bir risk taşır.

### Kartların rolü

- **Kahraman:** Gece otomatik savaşır; gündüz konumu ve davranış önceliği belirlenir.
- **Yapı:** Yol üzerinde tuzak, destek, iyileştirme veya savunma sağlar.
- **Beceri:** Bir Kahramanın gece davranışını değiştirir; örneğin en zayıf hedefi seçme, geri çekilme veya koruma.
- **Büyü:** Gece savaşına anlık müdahaledir; kullanım sayısı sınırlıdır.

### Yükseltme sistemi

Yükseltmeler yalnızca Gündüz evresinde ve Moral harcanarak yapılır. Bir kart yükseldiğinde yeni bir **davranış seçeneği** açılır.

Örnek Kahraman gelişimi:

- **Avcı Seviye 1:** En yakındaki hedefe saldırır.
- **İz Sürücü dalı:** Canı en düşük hedefi avlar.
- **Canavar Avcısı dalı:** Yüksek seviyeli hedeflere ilave hasar verir.

Örnek Yapı gelişimi:

- **Şifa Çadırı:** Tek hedefi güçlü iyileştirir veya birden fazla hedefi az miktarda iyileştirir.

### Merkez Binasına saldırı

Gece sonunda rakip savunmasını aşarak yolun sonuna ulaşan Kahramanlar Merkez Binasına saldırır. Saldırıdan sonra hayatta kalanlar yolda kalır; otomatik olarak yok olmaz.

### Örnek oyun akışı

Oyuncu gündüz ağır bir Muhafızı öne, iki menzilli Kahramanı arkaya dizer. Rakip ilk hedefi sersemleten bir tuzak kurar. Gece başladığında oyuncu sınırlı müdahale hakkının birini Muhafızı korumak için kullanır, diğerini sonraki çatışmaya saklar. Hat bozulmadan ilerleyen birlikler gece sonunda Merkez Binasına ulaşır.

### Güçlü yanı ve tasarım riski

- **Güçlü yanı:** Hazırlık kararlarının sonucunu toplu ve görsel bir savaş olarak gösterir.
- **Risk:** Oyuncu gece evresinde kontrolünü kaybetmiş hissedebilir. Davranış kuralları önceden açıkça gösterilmeli ve sınırlı müdahale hakkı korunmalıdır.

---

## 5. Teknoloji Ağacı ve Merkez Binası Evrimi

### Ana fikir

Oyuncular yalnızca sahadaki kartları değil, kendi Merkez Binalarını da geliştirerek yeni kart seviyeleri ve stratejik yollar açar. Her oyuncu maç içinde **Savaş**, **Savunma** veya **Büyü** odaklı bir teknoloji ağacı kurar.

Bu model deste stratejisini maç içinde şekillendirmeyi ve farklı gelişim yollarını öne çıkarır.

### Savaş alanı

- Her oyuncunun iki ön cephe alanı, iki arka destek alanı ve bir Merkez Binası vardır.
- Kahramanlar ön cephede, çoğu Yapı arka alanda oynanır.
- Merkez Binasının üç teknoloji yuvası vardır.
- Sahadaki kart sayısı az, kartlar arasındaki birleşim ve gelişim etkisi yüksektir.

### Tur akışı

1. **Üretim:** Merkez Binası seçilmiş teknoloji dallarına göre kaynak üretir.
2. **Kart çekme:** Bir kart çekilir; gerekirse bir kart değiştirme hakkı kullanılır.
3. **Ana eylem:** Kahraman veya Yapı oynanır, saldırı yapılır ya da teknoloji geliştirilir.
4. **Destek eylemi:** Bir Beceri veya düşük maliyetli Büyü kullanılabilir.
5. **Araştırma:** O tur karşılanan görevlerden Araştırma puanı alınır.
6. **Tur sonu:** Teknoloji etkileri ve bekleme süreleri güncellenir.

### Kaynak sistemi

- **Enerji:** Bütün kartların temel oynama bedelidir ve her tur yenilenir.
- **Araştırma:** Teknoloji açmak ve kartları Seviye 2–3'e yükseltmek için kullanılır.
- Araştırma, farklı oyun davranışlarıyla kazanılır:
  - Hasar vermek Savaş araştırması sağlar.
  - Hasar engellemek Savunma araştırması sağlar.
  - Beceri ve Büyü zincirleri kurmak Büyü araştırması sağlar.

### Teknoloji dalları

| Dal | Oyun tarzı | Örnek açılımlar |
|---|---|---|
| Savaş | Hızlı ve saldırgan | Kahraman saldırı bonusu, ilave hareket, kuşatma hasarı |
| Savunma | Dayanıklılık ve karşı saldırı | Yapı zırhı, onarım, Merkez Binası kalkanı |
| Büyü | Kart birleşimleri ve kontrol | Mana indirimi, Büyü kopyalama, Beceri bekleme süresi azaltma |

Bir oyuncu bir dalda Seviye 3'e ulaşabilir veya iki dalı Seviye 2'de birleştirebilir. En güçlü sonuçlar farklıdır; tek bir doğru gelişim yolu olmamalıdır.

### Kartların rolü

- **Kahraman:** Teknoloji dallarına göre farklı yükseltme seçenekleri kazanır.
- **Yapı:** Üretim yapar, teknoloji bonuslarını sahaya taşır veya Merkez Binasını korur.
- **Beceri:** Kartların teknolojiyle açılan aktif yeteneklerini tetikler ve birleşimler kurar.
- **Büyü:** Büyü dalında güçlenir ancak diğer dallarda da taktik araç olarak kullanılabilir.

### Yükseltme sistemi

Bir Kahraman veya Yapı ancak ilgili teknoloji seviyesi açıldıktan sonra Araştırma harcanarak yükseltilebilir. Yükseltme seçeneği, oyuncunun teknoloji tercihine göre değişir.

Örnek:

- Savaş teknolojisine sahip **Golem**, Kuşatma Golemine dönüşüp Merkez Binasına ilave hasar verir.
- Savunma teknolojisine sahip **Golem**, Koruyucu Goleme dönüşüp Yapılara gelen hasarı üstlenir.
- Büyü teknolojisine sahip **Golem**, Rün Golemine dönüşüp kullanılan Büyülerden geçici güç kazanır.

### Merkez Binasına saldırı

Merkez Binası başlangıçta iki **Savunma Mührü** ile korunur. Ön cephede kazanılan her doğrudan saldırı önce bir Mührü kırar. Mühürler bittikten sonra sonraki saldırılar bina canını azaltır. Bazı kuşatma kartları Mühürlere karşı daha etkilidir.

Merkez Binasını teknoloji için geliştirmek güç kazandırır ancak onarım ve savunma için kullanılabilecek Araştırmayı tüketir. Böylece gelişme ile hayatta kalma arasında sürekli seçim yapılır.

### Örnek oyun akışı

Oyuncu ilk turlarda Savunma teknolojisiyle Yapılarını güçlendirir. Rakip bunu görüp Savaş dalında kuşatma kartlarına yönelir. Oyuncu ikinci dal olarak Büyüyü açar, koruyucu Yapılarına tepki Becerileri ekler ve rakibin büyük saldırısını durdurduktan sonra biriken Araştırmayla karşı hücuma geçer.

### Güçlü yanı ve tasarım riski

- **Güçlü yanı:** Aynı deste, maç içindeki tercihlere göre farklı biçimde oynanabilir.
- **Risk:** Çok sayıda yükseltme seçeneği dengeleme yükünü artırır. İlk sürümde her dal için az ama belirgin seçenek kullanılmalıdır.

---

## Modellerin Kısa Karşılaştırması

| Model | Ana strateji | Karmaşıklık | Tempo | En güçlü oyuncu deneyimi |
|---|---|---:|---:|---|
| Üç Koridorlu Kuşatma | Koridor üstünlüğü | Düşük | Orta–hızlı | Doğrudan çatışma |
| Bölge Kontrolü ve İkmal | Harita ve ekonomi | Yüksek | Orta | Uzun vadeli planlama |
| Gizli Emirler | Tahmin ve karşı hamle | Orta–yüksek | Hızlı | Blöf ve zihin oyunu |
| Gündüz/Gece Kuşatması | Dizilim ve hazırlık | Orta | Dalgalı | Otomatik savaş gösterisi |
| Teknoloji Ağacı | Maç içi gelişim | Yüksek | Orta–yavaş | Kişiselleştirme ve kart birleşimleri |

## İlk Prototip İçin Öneri

İlk oynanabilir sürüm için **Üç Koridorlu Kuşatma** en uygun başlangıç modelidir. Kuralları hızlı anlaşılır, mevcut kart yuvası yaklaşımına doğrudan uyar ve Kahraman, Yapı, Beceri, Büyü ile yükseltme sistemlerinin tümünü küçük bir savaş alanında test etmeyi sağlar.

İkinci prototip adayı **Gündüz Hazırlığı, Gece Kuşatması** olabilir. Oyunu diğer kart savaşlarından ayıracak daha belirgin bir kimlik sunar; ancak otomatik savaş davranışlarının iyi anlatılması gerekir.

İlk prototipte yalnızca şu kapsam yeterlidir:

- Her türden 6 kart olmak üzere toplam 24 kart,
- Üç koridor,
- Kahraman ve Yapılar için ikişer yükseltme dalı,
- Tek bir enerji kaynağı,
- Yapay zekâya karşı veya yerel iki oyunculu maç,
- Yaklaşık 15 dakikalık hedef maç süresi.
