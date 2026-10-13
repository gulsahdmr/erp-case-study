# Bölüm 5: Yetkilendirme ve Güvenlik

## 1. Rol Bazlı Yetki Matrisi

Sistemdeki 4 rolün fonksiyonel yetki dağılımı aşağıdaki matriste tanımlanmıştır:

| Fonksiyonel Alan | Satınalma Uzmanı | Depo Personeli | Üretim Planlama | Sistem Yöneticisi |
|---|:---:|:---:|:---:|:---:|
| **Ürün Kartı (Item)** | Okuma / Güncelleme | Sadece Okuma | Sadece Okuma | Tam Yetki (CRUD) |
| **Tedarikçi Kartı (Supplier)** | Ekleme / Güncelleme / Okuma | Erişim Yok | Erişim Yok | Tam Yetki (CRUD) |
| **Satınalma Siparişi (PO) Oluşturma** | **Tam Yetki (Create/Update)** | Erişim Yok | Satınalma Talebi Açabilir | Tam Yetki (CRUD) |
| **Sipariş Kalem Fiyatları** | **Görür (Read/Write)** | ❌ **Maskelenir (Erişim Yok)** | Erişim Yok | Görür |
| **Mal Kabul (Goods Receipt) Girişi** | ❌ **YASAK (Sadece Okur)** | **Tam Yetki (Create/Read)** | Sadece Okuma | Tam Yetki (CRUD) |
| **Güncel Stok Miktarları** | Sadece Okuma | Sadece Okuma | Sadece Okuma | Tam Yetki |
| **Depo Sayım / Stok Düzeltme** | Erişim Yok | Giriş Yapabilir (Onaya Gider) | Erişim Yok | Onaylar / Tam Yetki |
| **Kullanıcı ve Rol Yönetimi** | Erişim Yok | Erişim Yok | Erişim Yok | **Tam Yetki** |

> 📌 **Kritik İlke - Görevler Ayrılığı (Separation of Duties - SoD):**  
> Sahtecilik ve suistimal riskini engellemek adına; satınalma siparişini oluşturan kişi mal kabulü fiziksel veya sistemsel olarak teslim alamaz. Depocu ise mal kabul fişi kesebilir ancak sipariş oluşturamaz ve ürün birim maliyetlerini göremez.

---

## 2. Yetkilendirme Modeli Tasarımı (RBAC - Role-Based Access Control)

Sistemde yetkilendirme doğrudan kullanıcı bazlı değil, **Rol Tabanlı Erişim Kontrolü (RBAC)** modeli üzerinden kurgulanmıştır.

### A) Veritabanı Tablo Mimarisi
* **AppUser:** Kullanıcı ana tablosu (`UserID`, `Username`, `PasswordHash`, `Email`, `IsActive`)
* **AppRole:** Rol tanımları (`RoleID`, `RoleCode`, `RoleName`)
* **AppPermission:** Detaylı işlem izinleri (`PermissionID`, `PermissionCode`, `Description`)  
  *Örnek izinler:* `PO_CREATE`, `PO_APPROVE`, `PO_VIEW`, `GR_CREATE`, `STOCK_VIEW`
* **AppUserRole:** Kullanıcı - Rol eşleşme tablosu (Çoka-çok ilişki)
* **AppRolePermission:** Rol - İzin eşleşme tablosu (Çoka-çok ilişki)

```
[AppUser] ──< [AppUserRole] >── [AppRole] ──< [AppRolePermission] >── [AppPermission]
```

### B) API ve Servis Katmanı Güvenliği
1. **Kimlik Doğrulama (Authentication):** Stateless **JWT (JSON Web Token)** mimarisi kullanılır. Kullanıcı login olduğunda roller ve claim'ler token içine gömülür.
2. **Yetki Doğrulama (Authorization Middleware):** API controller/endpoint seviyesinde attribute bazlı kontrol uygulanır:
   ```csharp
   [HttpPost("api/goods-receipts")]
   [Authorize(Policy = "RequireGoodsReceiptCreate")] // Sadece depo personeli ve admin
   public IActionResult CreateGoodsReceipt(...)
   ```

---

## 3. Dikkate Alınan Temel Güvenlik Riskleri

### A) Dolandırıcılık ve İç Tehditler (Fraud & Internal Abuse)
* **Risk:** Hayali sipariş açılıp depoya girmeden kabul edilmiş gibi gösterilmesi.
* **Önlem:** Çift onay mekanizması (Four-Eyes Principle / Maker-Checker) ve SoD kontrolleri.

### B) Stok Verisinin Manipülasyonu (Data Tampering)
* **Risk:** Depodaki eksiklerin `StockTransaction` tablosundan silinerek gizlenmesi.
* **Önlem (Immutability):** Stok hareket tablosu **yalnızca INSERT edilebilir (Append-Only)** olarak kurgulanmıştır. `DELETE` ve `UPDATE` yetkisi veritabanı seviyesinde `DENY` ile kapatılmıştır. Hatalı işlemler ters hareket (Storno) ile dengelenir.

### C) Ticari Sırların ve Fiyatların Gizliliği (Data Masking)
* **Risk:** Depo veya üretim personelinin tedarikçi anlaşma fiyatlarını dışarı sızdırması.
* **Önlem:** API yanıtlarında `Role != Purchasing` olan kullanıcılara `UnitPrice` ve `LineTotal` alanları `null` veya maskeli olarak döndürülür (Least Privilege Prensibi).

### D) Denetim İzi ve Hesap Verebilirlik (Audit Logging)
* **Risk:** Yetkisiz veya hatalı bir işlemin kim tarafından yapıldığının tespit edilememesi.
* **Önlem:** Kritik tablolar (`PurchaseOrder`, `GoodsReceipt`, `StockTransaction`) için `CreatedBy`, `CreatedAt`, `IPAddress` bilgileri kaydedilir. Ayrıca `AuditLog` tablosu ile eski ve yeni değerlerin JSON farkı (Diff) saklanır.

### E) Uygulama Güvenliği (OWASP Standartları)
* **SQL Injection:** Tüm SQL sorguları ORM (Entity Framework) veya parametreli sorgularla çalışır; string birleştirme engellenmiştir.
* **Rate Limiting:** API endpoint'lerine brute-force saldırılarını engellemek amacıyla istek sınırı uygulanır.
