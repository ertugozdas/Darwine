# Godot 4 Kart Sistemi Kullanım Rehberi

Bu rehber, projenizde oluşturduğumuz modüler kart sistemini (`BaseCard`, `HeroCard`, `SettlementCard`, `SpecialPowerCard`, `UpgradeCard`) ve kart yuvalarını (`CardSlot`) Godot 4 editöründe ve kod üzerinde nasıl bir araya getireceğinizi adım adım açıklar.

---

## 1. Kart Sistemi Genel Yapısı (Hiyerarşi)

Sistemimiz tamamen modüler bir OOP (Nesne Yönelimli Programlama) yapısındadır.
- **CardSlot**: Kartların yerleşeceği grid alanlarındaki yuvaları temsil eder.
- **CardDatabase**: Kart verilerini tür bazlı JSON dosyalarından okur.
- **BaseCard**: Tüm kartların temelidir. Sürükleme, geri dönme, hizalanma ve genel UI bileşenlerini yönetir.
  - ↳ **HeroCard**: Atak, Zırh ve Can değerlerine sahip karakter kartlarıdır.
  - ↳ **SettlementCard**: Can ve isteğe bağlı Atak değeri içeren, pasif veya aktif yerleşkelerdir.
  - ↳ **UpgradeCard**: Kahraman veya yerleşkeleri güçlendiren ekipman/geliştirme kartlarıdır.
  - ↳ **SpecialPowerCard**: Tek seferlik büyü veya özel yetenek kartlarıdır.

---

## 2. Kart Verileri (JSON)

Kartların isim, açıklama, maliyet, nadirlik, stat ve görsel bilgileri sahneye yazılmaz. Her kart türü kendi JSON dosyasından okunur:

- `res://data/cards/heroes.json`
- `res://data/cards/settlements.json`
- `res://data/cards/special_powers.json`
- `res://data/cards/upgrades.json`

Yeni kart eklerken ilgili tür dosyasına yeni bir obje ekleyin ve sahnedeki veya kodla oluşturulan kart düğümünde sadece `card_id` değerini bu objenin `id` değeriyle eşleştirin.

Örnek kahraman verisi:

```json
{
  "id": "sovalye",
  "name": "Şövalye",
  "description": "Zırhlı kraliyet muhafızı.",
  "energy_cost": 2,
  "rarity": "RARE",
  "attack": 3,
  "armor": 2,
  "health": 6,
  "image_url": "res://images/cards/knight.png"
}
```

---

## 3. Kart Template Sahneleri

Her kart türü ve nadirlik için ayrı template sahneleri `res://scenes/card_templates/` altında hazırdır:

- `hero_common.tscn`, `hero_rare.tscn`, `hero_epic.tscn`, `hero_legendary.tscn`
- `settlement_common.tscn`, `settlement_rare.tscn`, `settlement_epic.tscn`, `settlement_legendary.tscn`
- `special_power_common.tscn`, `special_power_rare.tscn`, `special_power_epic.tscn`, `special_power_legendary.tscn`
- `upgrade_common.tscn`, `upgrade_rare.tscn`, `upgrade_epic.tscn`, `upgrade_legendary.tscn`
- `effect_common.tscn`, `effect_rare.tscn`, `effect_epic.tscn`, `effect_legendary.tscn`

Standart kartların sabit semantik ikonları dört ortak çerçeve PNG'sine gömülüdür:

- `hero_frame.png`: Enerji, saldırı, zırh ve can
- `settlement_frame.png`: Enerji, saldırı ve can
- `spell_frame.png`: Enerji, güç türü ve etki şiddeti
- `upgrade_frame.png`: Enerji, hedef, saldırı, zırh ve can

Çalışma anında ikon node'u üretilmez; yalnızca kart resmi ile sayısal/metinsel değerler hazır alanlara yazılır. Enerji maliyeti, sabit sarı şimşek ikonunun yanındaki `GoldLabel` alanında gösterilir. `effect_*` kartları oynama maliyeti taşımadığı için enerji rozeti göstermez ve ayrı, metin odaklı yüzeyini korur.

Bu sahnelerde kart resmi alanı ve değer alanları ayrı node olarak durur. Yerlerini değiştirebilirsiniz; runtime veri basmaya devam etmesi için node isimlerini koruyun:

- Genel alanlar: `TemplateBackground`, `TypeLabel`, `RarityLabel`, `ArtRect`, `ArtPlaceholderLabel`, `NameLabel`, `DescLabel`, `GoldBadge/GoldLabel`
- Kahraman: `AttackBadge/AttackLabel`, `ArmorBadge/ArmorLabel`, `HealthBadge/HealthLabel`
- Yerleşim: `AttackBadge/AttackLabel`, `HealthBadge/HealthLabel`
- Özel güç: `PowerTypeLabel`, `IntensityLabel`
- Geliştirme: `AllowedTargetsLabel`, `AttackBadge/AttackLabel`, `ArmorBadge/ArmorLabel`, `HealthBadge/HealthLabel`

İkonlu çerçeveleri yeniden üretmek için proje kökünde şu komutu çalıştırın:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/bake_card_template_icons.gd
```

Üretici her seferinde `res://images/cards/templates/source/plain/` altındaki dokunulmamış çerçeveleri kaynak alır; bu nedenle tekrar çalıştırıldığında ikonları üst üste bindirmez. Kart arkaplanını değiştirmek için önce ilgili düz kaynak PNG'yi güncelleyin, üreticiyi çalıştırın ve template sahnesindeki `CardFrame/TemplateBackground` referansını koruyun.

---

## 4. Editörde Sahne Kurulumu (Visual Setup)

Kartların sürüklenip bırakılabileceği temel bir savaş alanı sahnesi kurmak için aşağıdaki adımları izleyin:

### Adım 2.1: Kart Yuvalarını (Grid/Slot) Oluşturma
1. Sahnenize bir `GridContainer` veya `HBoxContainer` ekleyin. Adını `CardSlotsContainer` yapın.
2. Bu konteynerin içine birkaç adet `PanelContainer` ekleyin (örneğin 3 adet).
3. Bu `PanelContainer` düğümlerinin `Custom Minimum Size` değerini `Vector2(210, 290)` yapın (kart boyutlarından biraz daha geniş olmalıdır).
4. Her bir panele sağ tıklayıp **Attach Script** deyin ve `res://scripts/card_slot.gd` scriptini seçin.

### Adım 2.2: Kartları Oluşturma (Oyuncu Eli)
1. Sahnenin altına kartları tutacak bir `HBoxContainer` ekleyin. Adını `PlayerHand` yapın.
2. El alanının içine bir adet `Control` düğümü ekleyin.
3. Bu `Control` düğümünün `Size` değerini `Vector2(200, 280)` yapın.
4. Sağ tıklayıp **Attach Script** deyin ve yapmak istediğiniz kart tipine göre bir script seçin (Örn: `res://scripts/hero_card.gd`).
5. Düğümü seçtiğinizde Inspector panelinde şu değişkenleri göreceksiniz:
   - **Card Id**: JSON dosyasındaki kart kimliği (Örn: `sovalye`)
   - **Owner Id**: Kartın sahibi olan oyuncu.
   - **Is Draggable**: Kartın sürüklenip sürüklenemeyeceği.
   - **Card Template**: Kart çerçevesi/layout resmi (Boş bırakırsanız nadirlik rengine göre otomatik çizilir).

---

## 5. Kod Üzerinden Kart Oluşturma (Dinamik Spawning)

Kartları sahnede elle oluşturmak yerine oyun akışında kodla (örneğin desteden kart çekerken) oluşturmak için aşağıdaki yöntemi kullanabilirsiniz:

```gdscript
extends Node2D

# Kart scriptlerini referans alıyoruz
const HERO_CARD_SCRIPT = preload("res://scripts/hero_card.gd")
const UPGRADE_CARD_SCRIPT = preload("res://scripts/upgrade_card.gd")

@onready var hand_container = $PlayerHand

func _ready():
	# Test amaçlı el başlar başlamaz bir kahraman kartı çekelim
	draw_hero_card("sovalye", 1)

## Dinamik Kahraman Kartı Oluşturma Fonksiyonu
func draw_hero_card(card_id: String, owner_id: int):
	# 1. Boş bir Control node oluşturuyoruz
	var new_card = Control.new()
	new_card.custom_minimum_size = Vector2(200, 280)
	new_card.size = Vector2(200, 280)
	
	# 2. Scriptimizi bu node'a bağlıyoruz
	new_card.set_script(HERO_CARD_SCRIPT)
	
	# 3. Kart verisi JSON'dan card_id ile okunur
	new_card.card_id = card_id
	new_card.owner_id = owner_id
	
	# 4. Oyuncunun eline ekliyoruz
	hand_container.add_child(new_card)
```

---

## 6. Gelişmiş Etkileşimler (Kart Eşleme / Upgrade Sistemi)

Sürükle bırak özelliğinde kartın bir slota bırakıldığını veya bir kartın diğer kart üzerine bırakıldığını tespit etmek için `BaseCard` içindeki `_stop_dragging` fonksiyonuna ekleme yapabilir ya da kart yuvası üzerinden olayları dinleyebilirsiniz.

### Örnek: Bir "Geliştirme" (Upgrade) kartını slottaki "Kahraman" kartına takmak
Eğer bir geliştirme kartını, içinde zaten kahraman olan bir slotun üzerine bırakırsak kahramanın statlarını arttırıp geliştirme kartını yok edebiliriz.

Bunu yapmak için `res://scripts/base_card.gd` dosyasındaki `_stop_dragging()` fonksiyonuna şu mantığı entegre edebilirsiniz:

```gdscript
# res://scripts/base_card.gd içindeki _stop_dragging() fonksiyonunun içi:

func _stop_dragging() -> void:
	if not is_dragging:
		return
	is_dragging = false
	
	if _active_hovered_slot:
		var slot = _active_hovered_slot
		_active_hovered_slot = null
		slot.highlight(false)
		
		# KURAL 1: Eğer bu kart bir "Geliştirme" (UpgradeCard) ise ve slot doluysa
		if self is UpgradeCard and slot.is_occupied:
			var target_card = slot.occupied_card
			# Slottaki kart bir Kahraman veya Yerleşke ise bonusları uygula
			if target_card has_method("_apply_upgrade"):
				target_card._apply_upgrade(self)
				# Geliştirme kartı kullanıldı, yok et
				queue_free()
				return
		
		# KURAL 2: Normal slota yerleşme mantığı (Slot boş ise)
		if slot.can_accept_card(self):
			current_slot = slot
			current_slot.accept_card(self)
			reparent(current_slot)
			var target_local_pos = (current_slot.size - size) / 2.0
			_target_global_position = current_slot.global_position + target_local_pos
			_is_snapping = true
			return
			
	# Slot bulunamadıysa veya yerleşim reddedildiyse ele geri dön
	_return_to_hand()
```

Ardından, `res://scripts/hero_card.gd` veya `res://scripts/settlement_card.gd` içerisine bu bonusu kabul edecek fonksiyonu ekleyin:

```gdscript
# res://scripts/hero_card.gd veya settlement_card.gd içine eklenecek fonksiyon:

func _apply_upgrade(upgrade_card: UpgradeCard) -> void:
	# Bonusları ekle
	if "attack" in self:
		self.attack += upgrade_card.bonus_attack
	if "armor" in self:
		self.armor += upgrade_card.bonus_armor
	if "health" in self:
		self.health += upgrade_card.bonus_health
		
	# UI güncellenecektir (setters tetikleneceği için)
	print(card_name + " geliştirildi! Yeni statlar: Atak:", attack, " Can:", health)
```

---

## 7. İpuçları & Tasarım Önerileri

1. **Çözünürlük ve Ölçekleme**: Kart boyutunu değiştirmek isterseniz `base_card.gd` içerisindeki `size = Vector2(200, 280)` varsayılan değerini editörden veya koddan istediğiniz gibi değiştirebilirsiniz. Pivot noktası otomatik olarak yeni merkeze ortalanacaktır.
2. **Konteyner Filtreleri**: Kart elinizdeyken diğer kartların üstüne gelebilmesi için el alanını tutan konteynerlerin (`HBoxContainer`) `Mouse -> Filter` özelliğini `Ignore` veya `Pass` yapın. Kartların kendisinde ise bu değer her zaman `Stop` kalmalıdır.
3. **Resim ve Şablon Çizimi**: Kendi tasarladığınız kart çerçevelerini `card_template` değişkenine atayabilirsiniz. Eğer şablon atarsanız sistem otomatik çizilen renkli sınır çizgilerini devre dışı bırakır ve sizin görselinizi kartın arka planına giydirir.
